[![Anarchy Tools compatible](https://img.shields.io/badge/Anarchy%20Tools-compatible-4BC51D.svg?style=flat)](http://anarchytools.org)
![License:apache](https://img.shields.io/hexpm/l/plug.svg)
![Swift:3](https://img.shields.io/badge/Swift-3-blue.svg)
![Platform:macOS](https://img.shields.io/badge/Platform-macOS-red.svg)
![Platform:Linux](https://img.shields.io/badge/Platform-Linux-red.svg)

# StandBack

![StandBack](art/standback-small.png)

StandBack is a regular expression engine implementing the `egrep` (POSIX-extended) language.  It is cross-platform and has no dependencies.
While `egrep` is a less popular language than PCRE, it is fully capable for basic programming tasks, and our API is *much* easier to use than Foundation's.

Here's a sample to get started. For more information, see our [documentation](http://standback-docs.sealedabstract.com).

# Mailing list

We use [discuss.sa](http://discuss.sealedabstract.com/c/code-sa/stand-back)


```swift
let r = try! Regex(pattern: "class[[:space:]]+([[:alnum:]]+)[[:space:]]*:CarolineTest[[:space:]]*\\{")
print(try! r.match("prefix stuff class Foo:CarolineTest {"))
```