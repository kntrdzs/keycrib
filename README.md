# Puska

Lebegő karakterpuska macOS-re, magyar billentyűzetkiosztáshoz. Az **Option + Ő** megnyitja és el is tünteti.

Windowsról átállva a legnehezebb megtalálni, hol van a `*`, a `:`, a `<` `>`, a `[` `]`, a `{` `}`, a `|`, a `\` vagy a `@`. Ez az app egy billentyűkombinációra megmutatja őket. Az ablak a többi ablak fölött marad, így miközben SQL-t vagy kódot írsz, oda tudsz rá nézni.

- Az **Option + Ő** előhozza, és ugyanez vagy az Esc el is tünteti.
- Ha egy sorra kattintasz, a karakter a vágólapra kerül.
- A karakterek kereshetők.
- A menüsorban egy billentyűzet-ikon jelzi, ennek menüjéből lehet bekapcsolni az indítást bejelentkezéskor.
- Nem kér engedélyt, és nem kapcsolódik a netre.

A kombinációk a macOS **Hungarian** kiosztásából vannak kiolvasva, nem fejből vannak felírva. Más kiosztásnál (például Hungarian – QWERTY vagy angol) mások lehetnek.

## Telepítés

Kell hozzá a Command Line Tools (ha még nincs fent: `xcode-select --install`), és macOS 13 vagy újabb.

```bash
git clone https://github.com/kntrdzs/puska.git
cd puska
./build.sh
```

A szkript lefordítja az appot, bemásolja az `/Applications` mappába, és elindítja.

## Testreszabás

- **A puska tartalma:** a `mac-billentyuk.html` fájlban van. A szerkesztés után futtasd újra a `./build.sh`-t.
- **A billentyűkombináció:** a `main.swift` `registerHotKey` függvényében állítható.

## Licenc

MIT
