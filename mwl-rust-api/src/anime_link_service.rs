use std::{
    cmp::{min, Ordering},
    collections::HashMap,
    sync::Arc,
};

use serde_json::Value;

use crate::{
    config::Config,
    model::{AnimeLink, AnimeQuery},
};
use futures::lock::Mutex;

pub struct AnimeLinkService {
    pub config: Config,
    pub link_map: Arc<Mutex<HashMap<String, AnimeLink>>>,
}

impl AnimeLinkService {
    async fn get_anime_db(&self) -> Option<Value> {
        let anime_db_url = self.config.secrets.anime_db_url.clone();
        if anime_db_url.is_empty() {
            println!("ANIME_DB_URL not configured, skipping anime DB fetch");
            return None;
        }
        println!("Fetching anime DB from: {}", anime_db_url);

        match reqwest::get(&anime_db_url).await {
            Ok(res) => match res.text().await {
                Ok(body) => match serde_json::from_str(&body) {
                    Ok(value) => {
                        println!("Anime DB loaded ({} bytes)", body.len());
                        Some(value)
                    }
                    Err(e) => {
                        eprintln!("Failed to parse anime DB JSON: {}", e);
                        None
                    }
                },
                Err(e) => {
                    eprintln!("Failed to read anime DB response: {}", e);
                    None
                }
            },
            Err(e) => {
                eprintln!("Failed to fetch anime DB: {}", e);
                None
            }
        }
    }

    fn extract_sources(&self, anime: &Value) -> Option<(String, AnimeLink)> {
        let sources_opt = anime.get("sources").and_then(|f| f.as_array());
        if sources_opt.is_none() {
            return None;
        }
        let anime_link: AnimeLink = anime.clone().into();
        let mal_id = anime_link.mal_id.clone();
        if mal_id.is_none() {
            return None;
        }
        let mal_id = mal_id.unwrap();
        Some((mal_id, anime_link))
    }

    fn parse_db_links(&self, anime_db: Value) -> HashMap<String, AnimeLink> {
        let sources: HashMap<String, AnimeLink> = anime_db
            .get("data")
            .unwrap()
            .as_array()
            .unwrap()
            .iter()
            .filter_map(|anime| self.extract_sources(anime))
            .map(|(mal_id, map)| (mal_id, map))
            .collect();
        sources
    }

    pub(crate) async fn setup_links(&self) {
        let anime_db_optional = self.get_anime_db().await;
        println!(
            "Anime DB captured at time: {}",
            chrono::Local::now()
        );
        if anime_db_optional.is_none() {
            println!("Failed to fetch anime DB");
            return;
        }
        let anime_db = anime_db_optional.unwrap();
        let links = self.parse_db_links(anime_db);

        let link_map = self.link_map.clone();
        let mut link_map = link_map.lock().await;

        for (mal_id, sources) in links {
            link_map.insert(mal_id, sources);
        }

        println!("Inserted {} links into link map", link_map.len());
    }

    pub(crate) async fn search(&self, anime_query: &AnimeQuery) -> Vec<AnimeLink> {
        let query = anime_query.query.clone().unwrap();
        let page = anime_query.page.unwrap_or(1);
        let size = anime_query.size.unwrap_or(20);
        let link_map = self.link_map.clone();
        let link_map = link_map.lock().await;
        let results = search_in_links_map(query, &link_map);
        let start = min(0, (page - 1) * size);
        let end = min(start.saturating_add(size), results.len());
        results[start..end].to_vec()
    }

    pub(crate) async fn get_link_by_id(&self, mal_id: &str) -> AnimeLink {
        let link_map = self.link_map.clone();
        let link_map = link_map.lock().await;
        let link = link_map.get(mal_id);
        match link {
            Some(l) => l.clone(),
            None => AnimeLink {
                mal_id: Some(mal_id.to_string()),
                title: None,
                anilist_id: None,
                kitsu_id: None,
                anime_planet: None,
                picture: None,
                year: None,
                synonyms: None,
                mean: 0.0,
            },
        }
    }

    pub(crate) async fn get_all_anime(&self) -> Vec<AnimeLink> {
        let link_map = self.link_map.clone();
        let link_map = link_map.lock().await;
        let mut links: Vec<AnimeLink> = link_map.values().cloned().collect();
        links.sort_by(compare_anime_links_by_mean_score);
        links
    }
}

fn compare_anime_links_by_mean_score(a: &AnimeLink, b: &AnimeLink) -> Ordering {
    b.mean
        .partial_cmp(&a.mean)
        .unwrap_or(Ordering::Equal)
}

fn search_in_links_map(
    query: String,
    link_map: &futures::lock::MutexGuard<'_, HashMap<String, AnimeLink>>,
) -> Vec<AnimeLink> {
    let query_lower = query.to_lowercase();
    link_map
        .iter()
        .filter(|(_, anime)| {
            if anime.title.is_none() {
                return false;
            }
            let title = anime.title.as_ref().unwrap();
            title.to_lowercase().contains(&query_lower)
                || anime
                    .synonyms
                    .as_ref()
                    .unwrap_or(&vec![])
                    .iter()
                    .any(|synonym| synonym.to_lowercase().contains(&query_lower))
        })
        .map(|(_, anime)| anime.clone())
        .collect::<Vec<AnimeLink>>()
}
