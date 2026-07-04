use serde::de::DeserializeOwned;
use tauri::{plugin::PluginApi, AppHandle, Runtime};

use crate::models::*;
use crate::Error;

pub fn init<R: Runtime, C: DeserializeOwned>(
    app: &AppHandle<R>,
    _api: PluginApi<R, C>,
) -> crate::Result<Iap<R>> {
    Ok(Iap(app.clone()))
}

/// 非 iOS 平台的空实现，所有调用返回 UnsupportedPlatform
pub struct Iap<R: Runtime>(#[allow(dead_code)] AppHandle<R>);

impl<R: Runtime> Iap<R> {
    pub fn get_products(&self, _req: GetProductsRequest) -> crate::Result<GetProductsResponse> {
        Err(Error::UnsupportedPlatform)
    }

    pub fn purchase(&self, _req: PurchaseRequest) -> crate::Result<PurchaseResponse> {
        Err(Error::UnsupportedPlatform)
    }

    pub fn restore_purchases(&self) -> crate::Result<TransactionsResponse> {
        Err(Error::UnsupportedPlatform)
    }

    pub fn get_unfinished_transactions(&self) -> crate::Result<TransactionsResponse> {
        Err(Error::UnsupportedPlatform)
    }

    pub fn finish_transaction(&self, _req: FinishTransactionRequest) -> crate::Result<()> {
        Err(Error::UnsupportedPlatform)
    }
}
