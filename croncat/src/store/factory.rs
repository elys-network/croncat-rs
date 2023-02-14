use serde::{Deserialize, Serialize};
use chrono::Utc;
use std::{collections::HashMap, fs, path::PathBuf};
use crate::{errors::Report};
use croncat_sdk_factory::msg::ContractMetadataInfo;

use super::get_storage_path;

/// Where our [`LocalCacheStorage`] will be stored.
const LOCAL_STORAGE_FILENAME: &str = "./cache.json";

/// Store the factory data cache
#[derive(Serialize, Deserialize, Clone)]
pub struct LocalCacheStorageEntry {
    pub expires: i64,
    pub latest: HashMap<String, [u8; 2]>,
    pub versions: HashMap<(String, [u8; 2]), ContractMetadataInfo>,
}

impl std::fmt::Debug for LocalCacheStorageEntry {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("LocalCacheStorageEntry")
            .field("expires", &self.expires.to_string())
            .field("latest", &self.latest)
            .field("versions", &self.versions)
            .finish()
    }
}

/// Store key pairs on disk and allow access to the data.
pub struct LocalCacheStorage {
    pub path: PathBuf,
    data: Option<LocalCacheStorageEntry>,
}

impl LocalCacheStorage {
    /// Create a new [`LocalCacheStorage`] instance with the default directory.
    pub fn new() -> Self {
        Self::from_path(get_storage_path())
    }

    /// Create a [`LocalCacheStorage`] instance at a specified path,
    /// if the data already exists at the directory we load it.
    pub fn from_path(path: PathBuf) -> Self {
        let data_file = path.join(LOCAL_STORAGE_FILENAME);

        // Load from the agent data file if it exists
        if data_file.exists() {
            let json_data = fs::read_to_string(data_file).unwrap();
            let data =
                serde_json::from_str(json_data.as_str()).expect("Failed to parse agent JSON data");
            Self { path, data }
        } else {
            // Otherwise create a new hashmap
            Self {
                path,
                data: None,
            }
        }
    }

    /// Write our data to disk at the specified location.
    pub fn write_to_disk(&self) -> Result<(), Report> {
        let data_file = self.path.join(LOCAL_STORAGE_FILENAME);

        // Create the directory to store our data if it doesn't exist
        if let Some(p) = data_file.parent() {
            fs::create_dir_all(p)?
        };

        fs::write(data_file, serde_json::to_string_pretty(&self.data)?)?;

        Ok(())
    }

    /// Insert a item into the data map.
    pub fn insert(
        &mut self,
        latest: Option<HashMap<String, [u8; 2]>>,
        versions: Option<HashMap<(String, [u8; 2]), ContractMetadataInfo>>,
    ) -> Result<Option<LocalCacheStorageEntry>, Report> {
      // Expires after 1 hour
        let dt = Utc::now();
        let expires = dt.timestamp().saturating_add(1 * 60 * 60 * 1000);

        let new_data = if let Some(data) = self.data {
            LocalCacheStorageEntry {
                expires,
                latest: latest.unwrap_or(data.latest),
                versions: versions.unwrap_or(data.versions),
            }
        } else {
            LocalCacheStorageEntry {
                expires,
                latest: latest.unwrap_or(HashMap::new()),
                versions: versions.unwrap_or(HashMap::new()),
            }
        };
        self.data = Some(new_data.clone());
        self.write_to_disk()?;
        Ok(Some(new_data))
    }

    /// Retrieve data, only if not expired
    pub fn get(&self) -> Option<LocalCacheStorageEntry> {
        if !self.is_expired() && self.has_latest_versions() {
          self.data
        } else {
          None
        }
    }

    /// Check if the data has expired
    pub fn is_expired(&self) -> bool {
        if let Some(data) = self.data {
            let dt = Utc::now();
            let now = dt.timestamp();
            now > data.expires
        } else { true }
    }

    /// Check if has latest versions
    pub fn has_latest_versions(&self) -> bool {
        if let Some(data) = self.data {
            data.latest.len() > 2
        } else { false }
    }

    /// Check if has latest versions
    pub fn has_all_versions(&self) -> bool {
        if let Some(data) = self.data {
            data.versions.len() > 2
        } else { false }
    }
}

impl Default for LocalCacheStorage {
    fn default() -> Self {
        Self::new()
    }
}
