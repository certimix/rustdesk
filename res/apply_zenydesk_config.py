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

        # Update RENDEZVOUS_SERVERS
        content = re.sub(
            r'pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[[^\]]*\];',
            'pub const RENDEZVOUS_SERVERS: &[&str] = &["zenydesk.com", "api.zenydesk.com.br"];',
            content
        )

        # Update RS_PUB_KEY
        content = re.sub(
            r'pub const RS_PUB_KEY: &str = "[^"]*";',
            'pub const RS_PUB_KEY: &str = "OeVuKk5nlHiXp+APNn0Y3pC1Iwpwn44JGqrQCsWqmBw=";',
            content
        )

        with open(config_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print("  -> libs/hbb_common/src/config.rs configured with ZenyDesk rendezvous server and pubkey.")
    else:
        print("  -> WARNING: libs/hbb_common/src/config.rs not found!")

    # 2. Update Cargo.lock package name if needed
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
