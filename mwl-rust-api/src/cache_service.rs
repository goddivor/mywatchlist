use std::collections::HashMap;
use std::sync::Arc;

use futures::lock::Mutex;
use serde::{de::DeserializeOwned, Serialize};

use crate::config::Config;

#[derive(Debug, Clone)]
pub struct CacheService {
    pub config: Config,
    redis: Option<Arc<Mutex<redis::aio::MultiplexedConnection>>>,
    memory: Arc<Mutex<HashMap<String, MemoryCacheEntry>>>,
}

#[derive(Debug, Clone)]
struct MemoryCacheEntry {
    data: String,
    expires_at: Option<i64>,
}

impl CacheService {
    pub async fn new(config: Config) -> Self {
        let redis_url = std::env::var("REDIS_URL").unwrap_or_default();
        let redis = if !redis_url.is_empty() {
            match redis::Client::open(redis_url.as_str()) {
                Ok(client) => match client.get_multiplexed_tokio_connection().await {
                    Ok(conn) => {
                        println!("Connected to Redis at {}", redis_url);
                        Some(Arc::new(Mutex::new(conn)))
                    }
                    Err(e) => {
                        eprintln!("Failed to connect to Redis: {}, falling back to in-memory", e);
                        None
                    }
                },
                Err(e) => {
                    eprintln!("Invalid Redis URL: {}, falling back to in-memory", e);
                    None
                }
            }
        } else {
            None
        };

        CacheService {
            config,
            redis,
            memory: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub async fn check_health(&self) {
        if self.redis.is_some() {
            println!("Cache service health check: OK (Redis)");
        } else {
            println!("Cache service health check: OK (in-memory fallback)");
        }
    }

    pub async fn get_cache_by_id<T: DeserializeOwned + Clone>(
        &self,
        content_type: &str,
        id: String,
    ) -> Option<T> {
        self.get_by_id(content_type, id, "CACHE").await
    }

    pub async fn get_link_by_id<T: DeserializeOwned + Clone>(
        &self,
        content_type: &str,
        id: String,
    ) -> Option<T> {
        self.get_by_id(content_type, id, "LINK").await
    }

    async fn get_by_id<T: DeserializeOwned + Clone>(
        &self,
        content_type: &str,
        id: String,
        pk_type: &str,
    ) -> Option<T> {
        let pk = format!("{}#{}_{}", pk_type, content_type, id);

        if let Some(redis) = &self.redis {
            let mut conn = redis.lock().await;
            let result: Option<String> = redis::cmd("GET")
                .arg(&pk)
                .query_async(&mut *conn)
                .await
                .ok()?;
            let data = result?;
            let vector: Vec<T> = serde_json::from_str(&data).ok()?;
            return vector.into_iter().next();
        }

        // Fallback: in-memory
        let store = self.memory.lock().await;
        let entry = store.get(&pk)?;
        if let Some(expires_at) = entry.expires_at {
            if chrono::Utc::now().timestamp() > expires_at {
                return None;
            }
        }
        let vector: Vec<T> = serde_json::from_str(&entry.data).ok()?;
        vector.into_iter().next()
    }

    pub async fn set_cache_by_id<T: Serialize + Send + Sync>(
        &self,
        content_type: &str,
        id: String,
        data: &T,
        expiry: Option<i64>,
    ) {
        self.set_by_id("CACHE", format!("{}_{}", content_type, id), data, expiry)
            .await;
    }

    pub async fn set_by_id<T: Serialize + Send + Sync>(
        &self,
        pk_type: &str,
        id: String,
        data: &T,
        expiry: Option<i64>,
    ) {
        let pk = format!("{}#{}", pk_type, id);
        let vec_data = vec![data];
        let value = serde_json::to_string(&vec_data).unwrap();

        if let Some(redis) = &self.redis {
            let mut conn = redis.lock().await;
            if let Some(ttl) = expiry {
                let _: Result<(), _> = redis::cmd("SETEX")
                    .arg(&pk)
                    .arg(ttl)
                    .arg(&value)
                    .query_async(&mut *conn)
                    .await;
            } else {
                let _: Result<(), _> = redis::cmd("SET")
                    .arg(&pk)
                    .arg(&value)
                    .query_async(&mut *conn)
                    .await;
            }
            return;
        }

        // Fallback: in-memory
        let expires_at = expiry.map(|ttl| chrono::Utc::now().timestamp() + ttl);
        let entry = MemoryCacheEntry {
            data: value,
            expires_at,
        };
        let mut store = self.memory.lock().await;
        store.insert(pk, entry);
    }

    pub async fn set_link_by_id(
        &self,
        id: &str,
        data: HashMap<String, String>,
        expiry: Option<i64>,
    ) {
        let pk = format!("LINK#{}", id);
        let value = serde_json::to_string(&data).unwrap();
        let wrapped = format!("[{}]", value);

        if let Some(redis) = &self.redis {
            let mut conn = redis.lock().await;
            if let Some(ttl) = expiry {
                let _: Result<(), _> = redis::cmd("SETEX")
                    .arg(&pk)
                    .arg(ttl)
                    .arg(&wrapped)
                    .query_async(&mut *conn)
                    .await;
            } else {
                let _: Result<(), _> = redis::cmd("SET")
                    .arg(&pk)
                    .arg(&wrapped)
                    .query_async(&mut *conn)
                    .await;
            }
            return;
        }

        // Fallback: in-memory
        let expires_at = expiry.map(|ttl| chrono::Utc::now().timestamp() + ttl);
        let entry = MemoryCacheEntry {
            data: wrapped,
            expires_at,
        };
        let mut store = self.memory.lock().await;
        store.insert(pk, entry);
    }

    pub async fn delete_by_id(&self, content_type: &str, id: String) {
        let pk = format!("CACHE#{}_{}", content_type, id);

        if let Some(redis) = &self.redis {
            let mut conn = redis.lock().await;
            let _: Result<(), _> = redis::cmd("DEL")
                .arg(&pk)
                .query_async(&mut *conn)
                .await;
            return;
        }

        let mut store = self.memory.lock().await;
        store.remove(&pk);
    }
}
