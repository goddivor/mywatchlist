use seahash::SeaHasher;
use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::hash::Hasher;
use std::sync::{Arc, Mutex};

use crate::model::{
    Anime, AnimeLink, AnimeQuery, Edge, RelatedAnime, RelationType, ReviewResponse,
    ReviewResponseData,
};

use crate::config::Config;
use crate::model_dto::{ContentGraphDTO, ContentNodeDTO};
use async_recursion::async_recursion;
use chrono::{DateTime, Utc};
use futures::{stream, StreamExt};

const REVIEW_SYSTEM: &str = "You are an anime/manga review critic, you are given the task to go through all the user reviews and provide a review under 500 words. Pros/Cons are optional but at least one should be present and 3 at max along with a final verdict. Don't hallucinate and don't contradict yourself in pros/cons. Output should be in the format { data: { pros: [ { title, description }, cons: [ { title, description }  ], verdict } }";

pub struct AnimeService {
    pub config: Config,
    pub mal_api: crate::mal_api::MalAPI,
    pub cache_service: crate::cache_service::CacheService,
    pub ai_service: crate::llm_client::LLMClient,
    pub anime_link_service: crate::anime_link_service::AnimeLinkService,
}

impl AnimeService {
    pub async fn get_related_anime(&self, id: i64) -> Result<ContentGraphDTO, Box<dyn Error>> {
        let mut graph = ContentGraphDTO {
            nodes: HashSet::new(),
            edges: Vec::new(),
        };
        self.get_related_anime_with_graph(id, &mut graph, false, true)
            .await?;
        Ok(graph)
    }

    #[async_recursion]
    pub async fn get_related_anime_with_graph(
        &self,
        id: i64,
        graph: &mut ContentGraphDTO,
        from_cache: bool,
        include_others: bool,
    ) -> Result<(), Box<dyn Error>> {
        let anime = self.get_anime_by_id(id, from_cache).await?;
        graph.nodes.insert(anime.clone().into());

        let unvisited_edges = self.filter_by_nodes(
            self.get_unvisited_edges(id, anime.related_anime.clone(), include_others),
            &graph.nodes,
        );

        let combined_edges: Arc<Mutex<Vec<Edge>>> = Arc::new(Mutex::new(Vec::new()));
        let combined_anime: Arc<Mutex<Vec<ContentNodeDTO>>> = Arc::new(Mutex::new(Vec::new()));

        stream::iter(unvisited_edges.clone())
            .for_each_concurrent(5, |edge| {
                let combined_edges = Arc::clone(&combined_edges);
                let combined_anime = Arc::clone(&combined_anime);
                async move {
                    if let Some((anime, edges_from_id)) = self.get_edges_from_id(edge.target).await {
                        let mut combined_edges = combined_edges.lock().unwrap();
                        combined_edges.extend(edges_from_id);
                        combined_anime.lock().unwrap().push(anime.clone().into());
                    }
                }
            })
            .await;

        graph
            .edges
            .extend(unvisited_edges.iter().map(|e| e.clone().into()));
        graph
            .nodes
            .extend(combined_anime.lock().unwrap().clone().into_iter());
        let filter_by_nodes =
            self.filter_by_nodes(combined_edges.lock().unwrap().clone(), &graph.nodes);

        for edge in filter_by_nodes.iter() {
            graph.edges.push(edge.clone().into());
            let _ = self
                .get_related_anime_with_graph(edge.target, graph, true, false)
                .await;
        }
        Ok(())
    }

    async fn get_edges_from_id(&self, id: i64) -> Option<(Anime, Vec<Edge>)> {
        match self.get_anime_by_id(id, true).await {
            Ok(anime) => {
                let vec = anime.related_anime.clone();
                Some((anime, self.get_unvisited_edges(id, vec, false)))
            }
            Err(e) => {
                eprintln!("Failed to get anime {}: {}", id, e);
                None
            }
        }
    }

    fn get_unvisited_edges(
        &self,
        id: i64,
        related_anime: Option<Vec<RelatedAnime>>,
        include_others: bool,
    ) -> Vec<Edge> {
        let mut unvisited_edges: Vec<Edge> = Vec::new();
        if let Some(related) = related_anime {
            unvisited_edges.extend(
                related
                    .iter()
                    .filter(|ra| self.valid_relation(&ra.relation_type, include_others))
                    .map(|ra| Edge {
                        source: id,
                        target: ra.node.id,
                        relation_type: ra.relation_type.clone(),
                    })
                    .collect::<Vec<Edge>>(),
            );
        }
        unvisited_edges
    }

    fn filter_by_nodes(&self, edges: Vec<Edge>, nodes: &HashSet<ContentNodeDTO>) -> Vec<Edge> {
        edges
            .iter()
            .filter(|edge| {
                !nodes.contains(&ContentNodeDTO {
                    id: edge.target,
                    ..Default::default()
                })
            })
            .cloned()
            .collect()
    }

    fn valid_relation(&self, relation_type: &RelationType, include_others: bool) -> bool {
        match relation_type {
            RelationType::AlternativeSetting => true,
            RelationType::Sequel => true,
            RelationType::Prequel => true,
            RelationType::AlternativeVersion => true,
            RelationType::SideStory => true,
            RelationType::ParentStory => true,
            RelationType::Summary => true,
            RelationType::FullStory => true,
            RelationType::SpinOff => true,
            RelationType::Character => false,
            RelationType::Other => include_others,
        }
    }

    async fn get_anime_by_id(&self, id: i64, from_cache: bool) -> Result<Anime, Box<dyn Error>> {
        let now = chrono::Utc::now();
        let result: Option<Anime> = match from_cache {
            true => {
                self.cache_service
                    .get_cache_by_id("anime", id.to_string())
                    .await
            }
            false => None,
        };

        if result.is_none() {
            println!(
                "{}: Cache miss anime: {}",
                now.format("%d/%m/%Y %H:%M:%S"),
                id
            );
            let anime = self.mal_api.get_anime_details(id).await?;

            self.cache_service
                .set_cache_by_id("anime", id.to_string(), &anime, None)
                .await;
            let then = chrono::Utc::now();
            self.log_anime(&anime, "Saved".to_string(), then, now);
            Ok(anime)
        } else {
            let anime = result.unwrap();
            let then = chrono::Utc::now();
            self.log_anime(&anime, "Cache hit".to_string(), then, now);
            Ok(anime)
        }
    }

    fn log_anime(
        &self,
        anime: &Anime,
        hit_or_miss: String,
        then: DateTime<Utc>,
        now: DateTime<Utc>,
    ) {
        println!(
            "{}: {} anime: {} and {} in {}ms",
            then.format("%d/%m/%Y %H:%M:%S"),
            hit_or_miss,
            anime.id,
            anime.title,
            then.timestamp_millis() - now.timestamp_millis()
        );
    }

    pub fn hash_str(&self, s: &str) -> String {
        let mut hasher = SeaHasher::new();
        hasher.write(s.as_bytes());
        let finish = hasher.finish();
        format!("{:x}", finish)
    }

    pub async fn summarize_review(
        &self,
        reviews: &str,
    ) -> Result<ReviewResponse, Box<dyn Error + Send + Sync>> {
        println!("Summarizing review {}", reviews.len());

        let hash_str = self.hash_str(reviews);

        println!("Using hash_key: {}", hash_str);

        let cached_review: Option<ReviewResponse> = self
            .cache_service
            .get_cache_by_id("reviews", hash_str.clone())
            .await;

        if let Some(review) = cached_review {
            return Ok(review);
        }

        println!("Cache miss for {}", hash_str);
        let json_str = self.ai_service.talk(REVIEW_SYSTEM, reviews).await?;
        let review_response_data: ReviewResponseData = serde_json::from_str(&json_str)?;

        let review_response = review_response_data.data.clone();

        self.cache_service
            .set_cache_by_id("reviews", hash_str, &review_response, Some(3600 * 24 * 30))
            .await;
        Ok(review_response)
    }

    pub async fn get_anime(&self, query: AnimeQuery) -> Vec<HashMap<String, String>> {
        let link: Vec<AnimeLink>;
        if query.query.is_some() {
            link = self.get_anime_by_query(&query).await;
        } else if query.mal_id.is_some() {
            link = self.get_anime_by_mal_id(&query).await;
        } else {
            link = self.get_all_anime().await;
        }
        create_map_using_fields(link, &query.fields)
    }

    async fn get_all_anime(&self) -> Vec<AnimeLink> {
        self.anime_link_service.get_all_anime().await
    }

    async fn get_anime_by_mal_id(&self, query: &AnimeQuery) -> Vec<AnimeLink> {
        let mal_id = query.mal_id.clone().unwrap();
        let anime_link = self.anime_link_service.get_link_by_id(&mal_id).await;
        vec![anime_link]
    }

    async fn get_anime_by_query(&self, query: &AnimeQuery) -> Vec<AnimeLink> {
        self.anime_link_service.search(query).await
    }
}

fn create_map_using_fields(
    link: Vec<AnimeLink>,
    fields: &[String],
) -> Vec<HashMap<String, String>> {
    let mut map: Vec<HashMap<String, String>> = Vec::new();
    for anime in &link {
        let mut hash_map: HashMap<String, String> = HashMap::new();
        for field in fields.iter() {
            match field.as_str() {
                "title" => {
                    if let Some(ref title) = anime.title {
                        hash_map.insert("title".to_string(), title.clone());
                    }
                }
                "malId" => {
                    if let Some(ref mal_id) = anime.mal_id {
                        hash_map.insert("malId".to_string(), mal_id.clone());
                    }
                }
                "anilistId" => {
                    if let Some(ref anilist_id) = anime.anilist_id {
                        hash_map.insert("anilistId".to_string(), anilist_id.clone());
                    }
                }
                "kitsuId" => {
                    if let Some(ref kitsu_id) = anime.kitsu_id {
                        hash_map.insert("kitsuId".to_string(), kitsu_id.clone());
                    }
                }
                "animePlanet" => {
                    if let Some(ref anime_planet) = anime.anime_planet {
                        hash_map.insert("animePlanet".to_string(), anime_planet.clone());
                    }
                }
                "picture" => {
                    if let Some(ref picture) = anime.picture {
                        hash_map.insert("picture".to_string(), picture.clone());
                    }
                }
                "synonyms" => {
                    if let Some(ref synonyms) = anime.synonyms {
                        hash_map.insert("synonyms".to_string(), synonyms.join(","));
                    }
                }
                "year" => {
                    if let Some(ref year) = anime.year {
                        hash_map.insert("year".to_string(), year.clone());
                    }
                }
                "mean" => {
                    hash_map.insert("mean".to_string(), anime.mean.to_string());
                }
                _ => {}
            }
        }
        map.push(hash_map);
    }
    map
}
