# Vim Setup

Your vim config lives in `home/shared/vim.nix` and applies to all hosts.

## What's Enabled

| Setting | Effect |
|---|---|
| Line numbers | Always visible on the left |
| Case-insensitive search | `/foo` matches `Foo`, `FOO`, etc. |
| Smart case | Typing a capital letter makes search case-sensitive again |
| Search highlighting | All matches light up as you search |
| Incremental search | Jumps to the first match as you type |
| Cursorline | Current line is highlighted |
| Show match | Briefly jumps to the matching bracket when you close one |
| Wildmenu | Tab in command mode shows a completion menu |
| Spaces for tabs | Tab key inserts spaces (2 globally, 4 in Python files) |
| Syntax highlighting | Colors for code |

---

## The Basics (Reminder)

Vim has **modes**. You start in Normal mode.

| Key | Action |
|---|---|
| `i` | Enter Insert mode (start typing) |
| `Esc` | Return to Normal mode |
| `:w` | Save |
| `:q` | Quit |
| `:wq` | Save and quit |
| `:q!` | Quit without saving |

---

## Moving Around (Normal Mode)

| Key | Movement |
|---|---|
| `h j k l` | Left / Down / Up / Right |
| `w` | Jump forward one word |
| `b` | Jump back one word |
| `0` | Start of line |
| `$` | End of line |
| `gg` | Top of file |
| `G` | Bottom of file |
| `42G` | Go to line 42 |
| `Ctrl-d` | Scroll half a page down |
| `Ctrl-u` | Scroll half a page up |

---

## Editing (Normal Mode)

| Key | Action |
|---|---|
| `x` | Delete character under cursor |
| `dd` | Delete (cut) current line |
| `yy` | Copy (yank) current line |
| `p` | Paste below current line |
| `u` | Undo |
| `Ctrl-r` | Redo |
| `o` | Open new line below and enter Insert mode |
| `O` | Open new line above and enter Insert mode |
| `A` | Append at end of line (enter Insert mode) |

---

## Searching (your config makes this nicer)

| Key | Action |
|---|---|
| `/foo` then Enter | Search forward for "foo" |
| `n` | Jump to next match |
| `N` | Jump to previous match |
| `:noh` | Clear search highlight |

Search is case-insensitive by default. Type a capital letter to make it case-sensitive.

---

## Command Mode Tips (`:`)

| Command | Action |
|---|---|
| `:w filename` | Save as a new file |
| `:%s/old/new/g` | Replace all occurrences of "old" with "new" |
| `:set number` | Turn on line numbers (already on by default) |
| `:syntax on` | Turn on syntax highlighting (already on) |

Press Tab after typing part of a command to use the wildmenu completion.
