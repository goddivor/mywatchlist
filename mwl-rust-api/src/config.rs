#[derive(Debug, Clone)]
pub struct Secrets {
    pub mal_client_id: String,
    pub bearer_secret: String,
    pub imagekit_private_key: String,
    pub llm_api_key: String,
    pub llm_model_name: String,
    pub llm_api_url: String,
    pub anime_db_url: String,
}

#[derive(Debug, Clone)]
pub struct Config {
    pub base_url: String,
    pub mal_api_url: String,
    pub secrets: Secrets,
}

impl Config {
    pub fn init() -> Config {
        let bearer_secret =
            std::env::var("BEARER_SECRET").expect("BEARER_SECRET must be set");
        let mal_client_id =
            std::env::var("MAL_CLIENT_ID").expect("missing MAL_CLIENT_ID");
        let base_url =
            std::env::var("BASE_URL").unwrap_or_else(|_| "http://0.0.0.0:8001".to_string());
        let mal_api_url =
            std::env::var("MAL_API_URL").unwrap_or_else(|_| "https://api.myanimelist.net/v2".to_string());
        let imagekit_private_key =
            std::env::var("IMAGEKIT_PRIVATE_KEY").unwrap_or_default();
        let llm_api_key =
            std::env::var("LLM_API_KEY").unwrap_or_default();
        let llm_model_name =
            std::env::var("LLM_MODEL_NAME").unwrap_or_else(|_| "gpt-4".to_string());
        let llm_api_url =
            std::env::var("LLM_API_URL").unwrap_or_default();
        let anime_db_url =
            std::env::var("ANIME_DB_URL").unwrap_or_default();

        let secrets = Secrets {
            mal_client_id,
            bearer_secret,
            imagekit_private_key,
            llm_api_key,
            llm_model_name,
            llm_api_url,
            anime_db_url,
        };

        Config { secrets, base_url, mal_api_url }
    }
}
