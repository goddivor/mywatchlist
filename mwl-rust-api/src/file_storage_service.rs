use crate::{config::Config, model::File};
use reqwest::{multipart, Response};
use serde::{Deserialize, Serialize};

pub struct FileStorageService {
    pub config: Config,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SignedURLResponse {
    #[serde(rename(serialize = "signedURL", deserialize = "signedURL"))]
    pub signed_url: String,
}

impl FileStorageService {
    fn is_configured(&self) -> bool {
        !self.config.secrets.imagekit_private_key.is_empty()
    }

    pub async fn get_image_url(
        &self,
        image_type: String,
        image_path: String,
        _expiry: i64,
    ) -> SignedURLResponse {
        if !self.is_configured() {
            return SignedURLResponse {
                signed_url: String::new(),
            };
        }

        // ImageKit serves images directly via URL endpoint
        let url = format!(
            "https://ik.imagekit.io/mwl/{}/{}",
            image_type, image_path
        );
        SignedURLResponse { signed_url: url }
    }

    pub async fn save_image(&self, image_type: String, image_path: String, file: File) {
        if !self.is_configured() {
            println!("ImageKit not configured, skipping save");
            return;
        }

        let private_key = &self.config.secrets.imagekit_private_key;
        let folder = format!("/{}", image_type);

        let part = multipart::Part::bytes(file.content)
            .file_name(file.file_name.clone())
            .mime_str(&file.content_type)
            .unwrap();

        let form = multipart::Form::new()
            .text("fileName", image_path)
            .text("folder", folder)
            .text("useUniqueFileName", "false")
            .part("file", part);

        let url = "https://upload.imagekit.io/api/v1/files/upload";
        println!("Uploading to ImageKit: {}", url);

        let client = reqwest::Client::new();
        let response = client
            .post(url)
            .basic_auth(private_key, Some(""))
            .multipart(form)
            .send()
            .await
            .unwrap();
        validate_response(response).await;
    }

    pub async fn delete_image(&self, image_type: String, image_path: String) {
        if !self.is_configured() {
            println!("ImageKit not configured, skipping delete");
            return;
        }

        let private_key = &self.config.secrets.imagekit_private_key;
        let file_path = format!("/{}/{}", image_type, image_path);

        // First, search for the file to get its fileId
        let search_url = format!(
            "https://api.imagekit.io/v1/files?path={}",
            file_path
        );
        let client = reqwest::Client::new();
        let search_response = client
            .get(&search_url)
            .basic_auth(private_key, Some(""))
            .send()
            .await
            .unwrap();

        let files: Vec<serde_json::Value> = search_response.json().await.unwrap_or_default();
        if let Some(file) = files.first() {
            if let Some(file_id) = file.get("fileId").and_then(|v| v.as_str()) {
                let delete_url = format!("https://api.imagekit.io/v1/files/{}", file_id);
                println!("Deleting from ImageKit: {}", delete_url);
                let response = client
                    .delete(&delete_url)
                    .basic_auth(private_key, Some(""))
                    .send()
                    .await
                    .unwrap();
                validate_response(response).await;
            }
        } else {
            println!("File not found on ImageKit: {}", file_path);
        }
    }
}

async fn validate_response(response: Response) -> String {
    let status = response.status();
    let text = response.text().await.unwrap();
    println!("Status: {:?} and Response: {}", status, text);
    if status.is_success() {
        text
    } else {
        panic!("Error in storage operation: {}", text);
    }
}
