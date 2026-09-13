# WordPop

Select a word anywhere on your Mac, press a hotkey, and get its definition, pronunciation, synonyms, antonyms, and rhymes in a popup at your cursor. Works offline. No accounts.

WordPop lives in the menu bar and stays out of the Dock.

## Features

- **Lookup from any app.** Select text in a browser, editor, PDF, chat window, or anywhere else, then press `⌃⌥⌘D`. The popup appears next to your mouse.
- **Quick Search.** Press `⌃⌥⌘S` to open a search bar and type a word directly, without selecting text first.
- **Definitions and examples** from the built-in macOS dictionary (the same data as Dictionary.app), parsed into numbered senses and sub-senses.
- **Pronunciation** shown as IPA, plus a speaker button that reads the word aloud with the system voice.
- **Synonyms and antonyms**, grouped by part of speech so "run" the verb and "run" the noun do not get mixed together.
- **Rhymes**, ranked by how common the word is.
- **Etymology**, one tap away.
- **Customizable shortcuts** and a **Launch at Login** toggle in Preferences.
- **Offline first.** Definitions, synonyms, antonyms, and rhymes all come from local data, so the popup is instant and works without a network. If you are online, WordPop also queries the [Datamuse API](https://www.datamuse.com/api/) in the background to add extra synonyms for words the local dataset covers thinly. The popup never waits on this.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode Command Line Tools (for `swift build`)
- Accessibility permission (WordPop needs it to capture your selected text)

## Install

```sh
git clone https://github.com/tilakp/wordpop.git
cd wordpop
./setup_signing.sh          # one-time, optional but recommended (see below)
./build_app.sh --install    # builds WordPop.app and copies it to /Applications
open /Applications/WordPop.app
```

On first launch, macOS asks for Accessibility permission. Grant it in **System Settings > Privacy & Security > Accessibility**. Without it, the lookup hotkey cannot read your selection.

### Why `setup_signing.sh`?

macOS ties the Accessibility grant to the app's code signature. An ad-hoc signed build gets a new signature on every rebuild, so the permission resets each time. `setup_signing.sh` creates a local self-signed certificate named "WordPop Local Signing" in your login keychain and trusts it for code signing. `build_app.sh` uses it automatically when present, so the grant survives rebuilds.

This only touches your login keychain. You can remove the certificate in Keychain Access at any time.

## Usage

| Action | Default shortcut |
| --- | --- |
| Look up selected word | `⌃⌥⌘D` |
| Open Quick Search | `⌃⌥⌘S` |

Both shortcuts can be changed from the menu bar icon under **Preferences**.

## How it works

- **Definitions, pronunciation, etymology:** macOS Dictionary Services (`DCSCopyTextDefinition`). WordPop parses the flat entry text that the system returns into structured senses.
- **Synonyms and antonyms:** a bundled JSON dataset generated from the [Open English WordNet](https://github.com/globalwordnet/english-wordnet) by `scripts/build_synonyms.py`.
- **Rhymes:** a bundled JSON dataset generated from the [CMU Pronouncing Dictionary](https://github.com/cmusphinx/cmudict) by `scripts/build_rhymes.py`, ranked using a general-English word frequency list.
- **Text capture:** simulates `⌘C` in the frontmost app, reads the clipboard, then restores the clipboard to its previous contents. This is the same technique PopClip and Alfred use. Accessibility permission is required to post the keystroke.

### Regenerating the datasets

```sh
cd scripts
pip3 install wn
python3 -c "import wn; wn.download('oewn:2021')"
python3 build_synonyms.py
python3 build_rhymes.py
cp synonyms.json antonyms.json rhymes.json ../Sources/WordPop/Resources/
```

## Project layout

```
Sources/WordPop/       Swift sources (AppKit + SwiftUI)
Sources/WordPop/Resources/  Bundled synonym, antonym, and rhyme datasets
Resources/             App icon and Info.plist
scripts/               Python scripts that build the datasets
build_app.sh           Builds and signs WordPop.app
setup_signing.sh       One-time local signing certificate setup
```

## Data attribution

- Open English WordNet is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- The CMU Pronouncing Dictionary is licensed under a BSD-style license.
- Definitions come from the dictionaries installed with macOS and are not redistributed by this project.

## License

[MIT](LICENSE)
