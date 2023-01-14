use clap::Parser;
use prometheus::{labels, opts, register_int_gauge, IntGauge};
use serde::Deserialize;
use warp::Filter;

#[derive(Parser, Debug)]
#[command(author="Christian Blades", version=env!("CARGO_PKG_VERSION"), about="a prometheus collector for mastodon server stats", long_about = None)]
struct Args {
    #[arg(short = 't', long = "host")]
    host: reqwest::Url,

    #[arg(short = 'b', long = "bind", default_value_t = ([0, 0, 0, 0], 9020).into())]
    bind: std::net::SocketAddr,
}

#[derive(Debug, Deserialize)]
struct Instance {
    stats: InstanceStats,
}

#[derive(Debug, Deserialize)]
struct InstanceStats {
    user_count: usize,
    status_count: usize,
    domain_count: usize,
}

#[derive(Debug)]
struct PrometheusEncodingError;

impl warp::reject::Reject for PrometheusEncodingError {}

#[tokio::main]
async fn main() {
    let Args { host, bind } = Args::parse();

    // set up the prometheus collectors
    let labels = labels! {"instance" => host.host_str().unwrap_or("UNKNOWN"), };
    let user_count: IntGauge = {
        let opts = opts!(
            "mastodon_users",
            "Total number of users on the instance",
            labels
        );
        register_int_gauge!(opts).unwrap()
    };
    let status_count: IntGauge = {
        let opts = opts!("mastodon_statuses", "Total number of all statuses", labels);
        register_int_gauge!(opts).unwrap()
    };
    let domain_count: IntGauge = {
        let opts = opts!(
            "mastodon_domains",
            "Number of domains this instance is aware of",
            labels
        );
        register_int_gauge!(opts).unwrap()
    };

    // scheme://host/api/v1/instance
    let instance_url = host.join("/api/v1/instance").unwrap();

    // collector loop
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(std::time::Duration::from_secs(60));
        interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);

        loop {
            interval.tick().await;

            let resp: Instance = reqwest::get(instance_url.clone())
                .await
                .unwrap()
                .json()
                .await
                .unwrap();

            user_count.set(resp.stats.user_count as i64);
            status_count.set(resp.stats.status_count as i64);
            domain_count.set(resp.stats.domain_count as i64);
        }
    });

    // /metrics endpoint
    let metrics_filter = warp::path!("metrics").and_then(|| async {
        let r = prometheus::default_registry().gather();
        let encoder = prometheus::TextEncoder::new();
        match encoder.encode_to_string(&r) {
            Ok(prom) => {
                return Ok(warp::reply::with_header(
                    prom,
                    "content-type",
                    prometheus::TEXT_FORMAT,
                ))
            }
            Err(_) => return Err(warp::reject::custom(PrometheusEncodingError)),
        }
    });

    warp::serve(metrics_filter).bind(bind).await;
}
