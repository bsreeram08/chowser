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

static URL_QUEUE: OnceLock<Mutex<Vec<String>>> = OnceLock::new();
static HANDLER_OBJECT: OnceLock<usize> = OnceLock::new();

fn queue() -> &'static Mutex<Vec<String>> {
    URL_QUEUE.get_or_init(|| Mutex::new(Vec::new()))
}

fn push_url(url: String) {
    if let Ok(mut guard) = queue().lock() {
        guard.push(url);
    }
}

pub fn take_pending_url() -> Option<String> {
    queue().lock().ok()?.pop()
}

extern "C" fn handle_get_url_event(_this: &Object, _cmd: Sel, event: id, _reply: id) {
    unsafe {
        let descriptor: id = msg_send![event, paramDescriptorForKeyword: KEY_DIRECT_OBJECT];
        let url = extract_string_from_descriptor(descriptor)
            .or_else(|| extract_string_from_descriptor(event));
        if let Some(url) = url {
            let trimmed = url.trim();
            if !trimmed.is_empty() {
                push_url(trimmed.to_owned());
            }
        }
    }
}

unsafe fn extract_string_from_descriptor(descriptor: id) -> Option<String> {
    if descriptor == nil {
        return None;
    }

    let string_value: id = msg_send![descriptor, stringValue];
    if string_value == nil {
        return None;
    }

    let utf8: *const c_char = msg_send![string_value, UTF8String];
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
