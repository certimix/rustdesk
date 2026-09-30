#!/usr/bin/env python3
import os
import re

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def apply_config():
    print(f"[ZenyDesk] Configuring ZenyDesk branding and servers in {REPO_ROOT}...")

    # 1. Update libs/hbb_common/src/config.rs
    config_path = os.path.join(REPO_ROOT, 'libs', 'hbb_common', 'src', 'config.rs')
    if os.path.isfile(config_path):
        with open(config_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Update APP_NAME
        content = re.sub(
            r'pub static ref APP_NAME: RwLock<String> = RwLock::new\("[^"]*"\.to_owned\(\)\);',
            'pub static ref APP_NAME: RwLock<String> = RwLock::new("ZenyDesk".to_owned());',
            content
        )

        # Update BUILTIN_SETTINGS
        builtin_replacement = """    pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new({
        let mut m = HashMap::new();
        m.insert("api-server".to_string(), "https://zenydesk.com".to_string());
        m
    });"""
        content = re.sub(
            r'(?m)^\s*pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = (Default::default\(\)|RwLock::new\(\{[\s\S]*?\n\s*\}\));',
            builtin_replacement,
            content
        )

        # Update RENDEZVOUS_SERVERS
        content = re.sub(
            r'pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[[^\]]*\];',
            'pub const RENDEZVOUS_SERVERS: &[&str] = &["zenydesk.com"];',
            content
        )

        # Update RS_PUB_KEY
        content = re.sub(
            r'pub const RS_PUB_KEY: &str = "[^"]*";',
            'pub const RS_PUB_KEY: &str = "AUDVAlSeBDEeu4WOGF1a05C6cXh14ZVxi4RP6L2knVQ=";',
            content
        )

        # Update LINK_DOCS_HOME
        content = re.sub(
            r'pub const LINK_DOCS_HOME: &str = "[^"]*";',
            'pub const LINK_DOCS_HOME: &str = "https://zenydesk.com";',
            content
        )

        # Update LINK_DOCS_X11_REQUIRED
        content = re.sub(
            r'pub const LINK_DOCS_X11_REQUIRED: &str = "[^"]*";',
            'pub const LINK_DOCS_X11_REQUIRED: &str = "https://zenydesk.com/suporte";',
            content
        )

        with open(config_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print("  -> libs/hbb_common/src/config.rs configured with ZenyDesk rendezvous server and pubkey.")
    else:
        print("  -> WARNING: libs/hbb_common/src/config.rs not found!")

    # 2. Update libs/hbb_common/src/lib.rs version check URL
    lib_path = os.path.join(REPO_ROOT, 'libs', 'hbb_common', 'src', 'lib.rs')
    if os.path.isfile(lib_path):
        with open(lib_path, 'r', encoding='utf-8') as f:
            lib_content = f.read()
        lib_content = lib_content.replace('https://api.rustdesk.com/version/latest', 'https://zenydesk.com/api/version/latest')
        with open(lib_path, 'w', encoding='utf-8') as f:
            f.write(lib_content)
        print("  -> libs/hbb_common/src/lib.rs version check URL updated to zenydesk.com.")

    # 3. Update src/common.rs default api-server fallback
    common_path = os.path.join(REPO_ROOT, 'src', 'common.rs')
    if os.path.isfile(common_path):
        with open(common_path, 'r', encoding='utf-8') as f:
            common_content = f.read()
        common_content = common_content.replace('"https://admin.rustdesk.com".to_owned()', '"https://zenydesk.com".to_owned()')
        with open(common_path, 'w', encoding='utf-8') as f:
            f.write(common_content)
        print("  -> src/common.rs default api-server fallback updated to zenydesk.com.")

    # 4. Update Cargo.lock package name if needed
    lock_path = os.path.join(REPO_ROOT, 'Cargo.lock')
    if os.path.isfile(lock_path):
        with open(lock_path, 'r', encoding='utf-8') as f:
            lock_content = f.read()
        if 'name = "rustdesk"\nversion = "1.4.9"' in lock_content:
            lock_content = lock_content.replace('name = "rustdesk"\nversion = "1.4.9"', 'name = "zenydesk"\nversion = "1.4.9"')
            with open(lock_path, 'w', encoding='utf-8') as f:
                f.write(lock_content)
            print("  -> Cargo.lock package name updated to 'zenydesk'.")
        else:
            print("  -> Cargo.lock already has 'zenydesk' package name.")

if __name__ == '__main__':
    apply_config()
