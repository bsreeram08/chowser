#![allow(unexpected_cfgs)]

use anyhow::{bail, Result};
use cocoa::base::{id, nil};
use objc::declare::ClassDecl;
use objc::runtime::{Class, Object, Sel};
use objc::{class, msg_send, sel, sel_impl};
use std::ffi::CStr;
use std::os::raw::c_char;
use std::sync::{Mutex, OnceLock};

const URL_EVENT_CLASS: u32 = u32::from_be_bytes(*b"GURL");
const URL_EVENT_ID: u32 = u32::from_be_bytes(*b"GURL");
const KEY_DIRECT_OBJECT: u32 = u32::from_be_bytes(*b"----");
const KEY_ADDRESS_ATTR: u32 = u32::from_be_bytes(*b"addr");
const KEY_SENDER_PID_ATTR: u32 = u32::from_be_bytes(*b"spid");

#[derive(Debug, Clone)]
pub struct PendingUrlEvent {
    pub url: String,
    pub source_app_id: Option<String>,
}

static URL_QUEUE: OnceLock<Mutex<Vec<PendingUrlEvent>>> = OnceLock::new();
static HANDLER_OBJECT: OnceLock<usize> = OnceLock::new();

fn queue() -> &'static Mutex<Vec<PendingUrlEvent>> {
    URL_QUEUE.get_or_init(|| Mutex::new(Vec::new()))
}

fn push_url(url: String, source_app_id: Option<String>) {
    if let Ok(mut guard) = queue().lock() {
        guard.push(PendingUrlEvent { url, source_app_id });
    }
}

pub fn take_pending_url_event() -> Option<PendingUrlEvent> {
    queue().lock().ok()?.pop()
}

extern "C" fn handle_get_url_event(_this: &Object, _cmd: Sel, event: id, _reply: id) {
    unsafe {
        let descriptor: id = msg_send![event, paramDescriptorForKeyword: KEY_DIRECT_OBJECT];
        let url = extract_string_from_descriptor(descriptor)
            .or_else(|| extract_string_from_descriptor(event));
        let source_app_id = extract_source_app_id(event);
        if let Some(url) = url {
            let trimmed = url.trim();
            if !trimmed.is_empty() {
                push_url(trimmed.to_owned(), source_app_id);
            }
        }
    }
}

unsafe fn extract_source_app_id(event: id) -> Option<String> {
    let address_descriptor: id = msg_send![event, attributeDescriptorForKeyword: KEY_ADDRESS_ATTR];
    if let Some(bundle_id) = extract_string_from_descriptor(address_descriptor).and_then(|value| {
        let trimmed = value.trim().to_owned();
        if trimmed.is_empty() {
            None
        } else {
            Some(trimmed)
        }
    }) {
        return Some(bundle_id);
    }

    let sender_descriptor: id =
        msg_send![event, attributeDescriptorForKeyword: KEY_SENDER_PID_ATTR];
    if sender_descriptor == nil {
        return None;
    }

    let pid: i32 = msg_send![sender_descriptor, int32Value];
    if pid <= 0 {
        return None;
    }

    let running_app: id =
        msg_send![class!(NSRunningApplication), runningApplicationWithProcessIdentifier: pid];
    if running_app == nil {
        return None;
    }

    let bundle_id: id = msg_send![running_app, bundleIdentifier];
    extract_string_from_descriptor(bundle_id).and_then(|value| {
        let trimmed = value.trim().to_owned();
        if trimmed.is_empty() {
            None
        } else {
            Some(trimmed)
        }
    })
}

unsafe fn extract_string_from_descriptor(descriptor: id) -> Option<String> {
    if descriptor == nil {
        return None;
    }

    let string_value: id = msg_send![descriptor, stringValue];
    if string_value != nil {
        return extract_utf8_string(string_value);
    }

    extract_utf8_string(descriptor)
}

unsafe fn extract_utf8_string(string_like: id) -> Option<String> {
    if string_like == nil {
        return None;
    }

    let utf8: *const c_char = msg_send![string_like, UTF8String];
    if utf8.is_null() {
        return None;
    }

    CStr::from_ptr(utf8).to_str().ok().map(ToOwned::to_owned)
}

fn ensure_handler_class() -> Result<*const Class> {
    if let Some(existing) = Class::get("ChowserURLHandler") {
        return Ok(existing as *const Class);
    }

    let superclass =
        Class::get("NSObject").ok_or_else(|| anyhow::anyhow!("NSObject class not available"))?;
    let mut decl = ClassDecl::new("ChowserURLHandler", superclass)
        .ok_or_else(|| anyhow::anyhow!("failed to create ChowserURLHandler class"))?;
    unsafe {
        decl.add_method(
            sel!(handleGetURLEvent:withReplyEvent:),
            handle_get_url_event as extern "C" fn(&Object, Sel, id, id),
        );
    }
    Ok(decl.register() as *const Class)
}

pub fn install_url_event_handler() -> Result<()> {
    unsafe {
        let handler_class = ensure_handler_class()?;
        let handler: id = msg_send![handler_class, new];
        if handler == nil {
            bail!("failed to allocate URL event handler object");
        }

        let manager: id = msg_send![class!(NSAppleEventManager), sharedAppleEventManager];
        if manager == nil {
            bail!("NSAppleEventManager is unavailable");
        }

        let _: () = msg_send![
            manager,
            setEventHandler: handler
            andSelector: sel!(handleGetURLEvent:withReplyEvent:)
            forEventClass: URL_EVENT_CLASS
            andEventID: URL_EVENT_ID
        ];

        let _ = HANDLER_OBJECT.set(handler as usize);
    }

    Ok(())
}
