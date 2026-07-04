use tauri::{
    plugin::{Builder, TauriPlugin},
    Manager, Runtime,
};

pub use models::*;

#[cfg(target_os = "ios")]
mod mobile;
#[cfg(not(target_os = "ios"))]
mod stub;

mod error;
mod models;

pub use error::{Error, Result};

#[cfg(target_os = "ios")]
use mobile::Iap;
#[cfg(not(target_os = "ios"))]
use stub::Iap;

pub trait IapExt<R: Runtime> {
    fn iap(&self) -> &Iap<R>;
}

impl<R: Runtime, T: Manager<R>> crate::IapExt<R> for T {
    fn iap(&self) -> &Iap<R> {
        self.state::<Iap<R>>().inner()
    }
}

/// Initializes the plugin.
pub fn init<R: Runtime>() -> TauriPlugin<R> {
    Builder::new("iap")
        .setup(|app, api| {
            #[cfg(target_os = "ios")]
            let iap = mobile::init(app, api)?;
            #[cfg(not(target_os = "ios"))]
            let iap = stub::init(app, api)?;
            app.manage(iap);
            Ok(())
        })
        .build()
}
