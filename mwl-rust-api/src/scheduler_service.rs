use std::env::var;

use axum::http::{HeaderMap, HeaderValue};
use tokio_cron_scheduler::{Job, JobScheduler};

pub async fn run_schedulers() {
    let mut sched = JobScheduler::new().await.unwrap();
    let cron_anime_links =
        var("ANIME_LINK_CRON").unwrap_or_else(|_| "0 0 0 * * *".to_string());
    println!(
        "Setting up scheduler with cron expression: {}",
        cron_anime_links
    );
    sched
        .add(
            Job::new_async(cron_anime_links, move |uuid, l| {
                Box::pin(async move {
                    trigger_schedule_update(uuid, l).await;
                })
            })
            .unwrap(),
        )
        .await
        .unwrap();

    sched.set_shutdown_handler(Box::new(|| {
        Box::pin(async move {
            println!("Scheduler shut down");
        })
    }));

    sched.start().await.unwrap();
    println!("Scheduler started");
}

async fn trigger_schedule_update(uuid: uuid::Uuid, mut l: JobScheduler) {
    println!("Scheduler triggered anime DB sync");
    let request = prepare_request();
    let client = reqwest::Client::new();
    match client.execute(request).await {
        Ok(response) => {
            println!("Scheduler sync response: {:?}", response.status());
        }
        Err(e) => {
            eprintln!("Scheduler sync failed: {}", e);
        }
    }
    let next_tick = l.next_tick_for_job(uuid).await;
    match next_tick {
        Ok(Some(ts)) => println!("Next sync scheduled for {:?}", ts),
        _ => println!("Could not get next tick for sync job"),
    }
}

fn prepare_request() -> reqwest::Request {
    let url = prepare_url();
    let mut request = reqwest::Request::new(reqwest::Method::POST, url.parse().unwrap());
    let mut header_map = HeaderMap::new();
    let token = var("BEARER_SECRET").unwrap();
    header_map.insert(
        "Authorization",
        HeaderValue::from_str(format!("Bearer {}", token).as_str()).unwrap(),
    );
    request.headers_mut().extend(header_map);
    request
}

fn prepare_url() -> String {
    let port = var("PORT").unwrap_or_else(|_| "8001".to_string());
    format!("http://0.0.0.0:{}/schedules", port)
}
