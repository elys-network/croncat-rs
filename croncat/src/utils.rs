//!
//! Helpers for dealing with local agents.
//!

use std::sync::{
    atomic::{AtomicU64, Ordering},
    Arc,
};

use color_eyre::Report;
use delegate::delegate;
use tokio::task::JoinHandle;

use croncat_sdk_agents::msg::AgentTaskResponse;

pub const DEFAULT_AGENT_ID: &str = "agent";
pub const DERIVATION_PATH: &str = "m/44'/118'/0'/0/0";

///
/// Count block received from the stream.
///
pub struct AtomicIntervalCounter {
    pub count: Arc<AtomicU64>,
    check_interval: u64,
}

impl AtomicIntervalCounter {
    /// Create a new [`AtomicIntervalCounter`] and check every 10 samples.
    pub fn new(interval: u64) -> Self {
        Self {
            count: Arc::new(AtomicU64::default()),
            check_interval: interval,
        }
    }

    /// Increase the current offset into the sample.
    pub fn tick(&self) {
        self.count.fetch_add(1, Ordering::SeqCst);
    }

    /// Determine if the count is a multiple of the integer interval.
    pub fn is_at_interval(&self) -> bool {
        let current_count = self.count.load(Ordering::Relaxed);

        current_count > 0 && current_count % self.check_interval == 0
    }
}

pub fn sum_num_tasks(tasks: &AgentTaskResponse) -> u64 {
    (tasks.stats.num_block_tasks + tasks.stats.num_cron_tasks).into()
}

///
/// Flatten join handle results.
///
pub async fn flatten_join<T>(handle: JoinHandle<Result<T, Report>>) -> Result<T, Report> {
    match handle.await {
        Ok(Ok(result)) => Ok(result),
        Ok(Err(err)) => Err(err),
        Err(err) => Err(err.into()),
    }
}

///
/// Block wrapper
///
#[derive(Debug, Clone)]
pub struct Block {
    pub inner: tendermint::Block,
}

#[allow(dead_code)]
impl Block {
    delegate! {
        to self.inner {
            pub fn header(&self) -> &tendermint::block::Header;
            pub fn data(&self) -> &Vec<Vec<u8>>;
        }
    }
}

impl From<tendermint::Block> for Block {
    fn from(block: tendermint::Block) -> Self {
        Self { inner: block }
    }
}

impl Ord for Block {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.header().height.cmp(&other.header().height)
    }
}

impl PartialOrd for Block {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(self.cmp(other))
    }
}

impl PartialEq for Block {
    fn eq(&self, other: &Self) -> bool {
        self.header().height == other.header().height
    }
}

impl Eq for Block {}

///
/// Block wrapper
///
#[derive(Debug, Clone)]
pub struct Status {
    pub inner: tendermint_rpc::endpoint::status::Response,
}

#[allow(dead_code)]
impl Status {
    delegate! {
        to self.inner {
            // find your inner self
        }
    }
}

impl From<tendermint_rpc::endpoint::status::Response> for Status {
    fn from(status: tendermint_rpc::endpoint::status::Response) -> Self {
        Self { inner: status }
    }
}

impl Ord for Status {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.inner
            .sync_info
            .latest_block_height
            .cmp(&other.inner.sync_info.latest_block_height)
    }
}

impl PartialOrd for Status {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(self.cmp(other))
    }
}

impl PartialEq for Status {
    fn eq(&self, other: &Self) -> bool {
        self.inner.sync_info.latest_block_height == other.inner.sync_info.latest_block_height
    }
}

impl Eq for Status {}

/// Normalize an rpc url that might not have a protocol.
pub fn normalize_rpc_url(rpc_url: &str) -> String {
    if rpc_url.starts_with("http://") || rpc_url.starts_with("https://") {
        rpc_url.to_string()
    } else {
        format!("https://{rpc_url}")
    }
}

pub fn is_error_fallible(e: &Report) -> bool {
    let msg = e.to_string().to_lowercase();
    msg.contains("agent not registered")
        || msg.contains("agent already registered")
        || msg.contains("already registered")
        || msg.contains("agent not found")
        || msg.contains("account not found")
        || msg.contains("failed to send funds")
        || msg.contains("needs whitelist approval")
        || msg.contains("Chain not found")
}

pub fn is_contract_error(e: &Report) -> bool {
    let msg = e.to_string().to_lowercase();
    msg.contains("execute wasm contract failed")
}
