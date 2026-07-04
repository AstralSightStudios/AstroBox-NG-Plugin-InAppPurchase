use serde::de::DeserializeOwned;
use tauri::{
    plugin::{PluginApi, PluginHandle},
    AppHandle, Runtime,
};

use crate::models::*;

tauri::ios_plugin_binding!(init_plugin_iap);

pub fn init<R: Runtime, C: DeserializeOwned>(
    _app: &AppHandle<R>,
    api: PluginApi<R, C>,
) -> crate::Result<Iap<R>> {
    let handle = api.register_ios_plugin(init_plugin_iap)?;
    Ok(Iap(handle))
}

/// Access to the StoreKit 2 IAP APIs.
pub struct Iap<R: Runtime>(PluginHandle<R>);

impl<R: Runtime> Iap<R> {
    pub fn get_products(&self, req: GetProductsRequest) -> crate::Result<GetProductsResponse> {
        self.0
            .run_mobile_plugin("getProducts", req)
            .map_err(Into::into)
    }

    pub fn purchase(&self, req: PurchaseRequest) -> crate::Result<PurchaseResponse> {
        self.0
            .run_mobile_plugin("purchase", req)
            .map_err(Into::into)
    }

    pub fn restore_purchases(&self) -> crate::Result<TransactionsResponse> {
        self.0
            .run_mobile_plugin("restorePurchases", ())
            .map_err(Into::into)
    }

    pub fn get_unfinished_transactions(&self) -> crate::Result<TransactionsResponse> {
        self.0
            .run_mobile_plugin("getUnfinishedTransactions", ())
            .map_err(Into::into)
    }

    pub fn finish_transaction(&self, req: FinishTransactionRequest) -> crate::Result<()> {
        self.0
            .run_mobile_plugin("finishTransaction", req)
            .map_err(Into::into)
    }
}
