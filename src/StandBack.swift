// Copyright (c) 2016 Drew Crawford.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// StandBack is a regular expression engine implementing the `egrep` (POSIX-extended) language.  It is cross-platform and has no dependencies.
/// While egrep is a less popular language than PCRE, it is fully capable for basic programming tasks, and our API is *much* easier to use than Foundation's.
/// let r = try! Regex(pattern: "class[[:space:]]+([[:alnum:]]+)[[:space:]]*:CarolineTest[[:space:]]*\\{")
/// print(try! r.match("prefix stuff class Foo:CarolineTest {"))

#if os(OSX)
import Darwin
#elseif os(Linux)
import Glibc
#endif

public enum RegexError: Error {
    ///The regexec() function failed to match
    case NoMatch
    ///Invalid regular expression
    case BadPattern
    ///invalid collating element
    case Collation
    ///invalid character class
    case CharacterClass
    ///`\` applied to unescapable character
    case Escape
    /// Invalid backreference number
    case SubExpression
    /// brackets `[ ]` not balanced
    case BracketBalance
    /// parentheses `( )` not balanced
    case ParenthesesBalance
    /// braces `{ }` not balanced
    case BraceBalance
    /// invalid character range in `[ ]`
    case Range
    /// ran out of memory
    case OutOfMemory
    /// `?`, `*`, or `+` operand invalid
    case Repeat
    /// empty (sub)expression
    ///- note: This error is only thrown on OSX
    case Empty
    /// cannot happen - you found a bug [in libc]
    ///- note: This error is only thrown on OSX
    case Bug
    /// e.g. negative-length string
    ///- note: This error is only thrown on OSX
    case InvalidArgument
    /// (bad multibyte character)
    ///- note: This error is only thrown on OSX
    case IllegalByteSequence
    /// Invalid use of back reference operator.
    ///- note: This error is only thrown on Linux
    case BadBackReference

    ///A nonspecific error
    ///- note: This error is only thrown on Linux
    case NonSpecific

    ///Compiled regular expression requires a pattern buffer larger than 64kb.
    ///- note: This error is only thrown on Linux
    case ExpressionTooComplex

    /// An error not in the POSIX specification.
    case ErrorNotInSpecification(Int)

    init(fromRegDiagnostic diagnostic: Int32) {
        #if os(OSX)
        let os_diagnostic = diagnostic
        #elseif os(Linux)
        let os_diagnostic = reg_errcode_t(diagnostic)
        #endif
        switch(os_diagnostic) {
        case REG_NOMATCH:
            self = RegexError.NoMatch
        case REG_BADPAT:
            self = RegexError.BadPattern
        case REG_ECOLLATE:
            self = RegexError.Collation
        case REG_ECTYPE:
            self = RegexError.CharacterClass
        case REG_EESCAPE:
            self = RegexError.Escape
        case REG_ESUBREG:
            self = RegexError.SubExpression
        case REG_EBRACK:
            self = RegexError.BracketBalance
        case REG_EPAREN:
            self = RegexError.ParenthesesBalance
        case REG_EBRACE:
            self = RegexError.BraceBalance
        case REG_ERANGE:
            self = RegexError.Range
        case REG_ESPACE:
            self = RegexError.OutOfMemory
        case REG_BADRPT:
            self = RegexError.Repeat
        default:
            //additional errors supported on Linux
            #if os(Linux)
            switch(os_diagnostic) {
                case REG_BADBR:
                self = RegexError.BadBackReference
                return
            case REG_EEND:
                self = RegexError.NonSpecific
                return
            case REG_ESIZE:
                self = RegexError.ExpressionTooComplex
                return
            default:
                break
            }
            #endif
            //additional errors supported on OSX
            #if os(OSX)
            switch(os_diagnostic) {
                case REG_EMPTY:
                self = RegexError.Empty
                return
                case REG_ASSERT:
                self = RegexError.Bug
                return
                case REG_INVARG:
                self = RegexError.InvalidArgument
                return
                case REG_ILLSEQ:
                self = RegexError.IllegalByteSequence
                return
                default:
                break
            }
            #endif


            self = RegexError.ErrorNotInSpecification(Int(diagnostic))
        }
    }
}

///We use an inner class as an implementation detail.  It isn't actually mutable, but it's hard to convince Swift that.
private final class RegexImp {
    fileprivate let regext: regex_t
    init(pattern: String) throws {
        var lregext = regex_t()
        let result = regcomp(&lregext, pattern, REG_EXTENDED)
        if result != 0 {
            throw RegexError(fromRegDiagnostic: result)
        }
        self.regext = lregext
    }
    deinit {
        var regext = self.regext
        regfree(&regext)
    }
}

///A match object.
public struct Match : CustomStringConvertible, CustomDebugStringConvertible {
    /// The start of the match (utf8 encoding)
    public let start : Int
    /// The end of the match (utf8 encoding)
    public let end : Int

    /// The length in UTF8 bytes of the match
    public var length: Int {
        return end - start
    }
    
    ///The string we searched to generate this match
    public let underlyingString : String
    
    ///The part of the string that matched this expression
    public var region: String {
        let utf8 = self.underlyingString.utf8
        return String(describing: utf8[utf8.index(utf8.startIndex, offsetBy: start)..<utf8.index(utf8.startIndex, offsetBy:end)])
    }
    private init?(start: Int, end: Int, underlyingString: String) {
        if start == -1 && end == -1 {return nil}
        self.start = start
        self.end = end
        self.underlyingString = underlyingString
    }
    fileprivate init?(regmatch: regmatch_t, underlyingString: String, offset: Int) {
        self.init(start: Int(regmatch.rm_so + offset), end: Int(regmatch.rm_eo + offset), underlyingString: underlyingString)
    }
    public var description: String {
        return region
    }
    public var debugDescription: String {
        return "<Match: \(region)>"
    }
}

///A result of a find operation
public struct FindResult {
    ///The entire part of the string that matched.
    public let entireMatch: Match
    
    ///Each group of the match.  Specify a group in parentheses.
    ///The `k`th group is the `k`th parentheses expression in the regex.
    ///If the group was unused, the element will be nil
    public let groups: [Match?]
}


public class FindResultGenerator: IteratorProtocol {
    public typealias Element  = FindResult
    var lastStart: Int = -1
    var lastMatch: Match? = nil
    let string: String
    let regex: Regex
    public func next() -> FindResultGenerator.Element? {
        let startPosition = (lastMatch?.end ?? 0) + 1
        lastStart = startPosition
        guard let proposedStartIndex = string.utf8.index(string.utf8.startIndex, offsetBy: startPosition, limitedBy: string.utf8.endIndex) else {
            return nil //index beyond range
        }
        let abbreviatedString = String(string.utf8[proposedStartIndex..<string.utf8.endIndex])!
        let result = try! regex.findFirst(inString: abbreviatedString, prefixSize: startPosition, entireString: string)
        lastMatch = result?.entireMatch
        return result
    }
    init(regex: Regex, string: String) { self.regex = regex; self.string = string }
}

public class FindResultSequence: Sequence {
    let generator: FindResultGenerator
    init(regex: Regex, string: String) { self.generator = FindResultGenerator(regex: regex, string: string) }
    typealias Generator = FindResultGenerator
    public func makeIterator() -> FindResultGenerator {
        return generator
    }
}

///A regular expression
public struct Regex {
    private let regexImp : RegexImp
    
    ///Create a regex following the given pattern.
    ///For regex syntax, consult the extended regular expression specification at http://pubs.opengroup.org/onlinepubs/7908799/xbd/re.html
    ///For casual use, Boost has a particularly good guide: http://www.boost.org/doc/libs/1_54_0/libs/regex/doc/html/boost_regex/syntax/basic_extended.html
    ///- note: There are two levels of indirection here.  For Swift literals, Swift-level escaping is applied first (e.g.  `\\` -> `\`).  
    ///  Therefore to escape through both systems, you may need `\\\\`.
    ///  See Swift's documentation on this here https://developer.apple.com/library/ios/documentation/Swift/Conceptual/Swift_Programming_Language/StringsAndCharacters.html
    public init(pattern: String) throws {
        regexImp = try RegexImp(pattern: pattern)
    }

    ///- parameter prefixSize: If you are searching a substring, pass a non-zero value here to get appropriate match groups
    ///- parameter entireString: If you are searching a substring, pass the entire string here to get appropriate match groups
    fileprivate func findFirst(inString string: String, prefixSize: Int, entireString: String) throws -> FindResult?   {
        var weDontMutateThis = self.regexImp.regext
        var matches: [regmatch_t] = [regmatch_t](repeating: regmatch_t(), count: self.regexImp.regext.re_nsub + 1)
        let result = regexec(&weDontMutateThis, string, matches.count, &matches, 0)
        #if os(OSX)
        let os_nomatch = REG_NOMATCH
        #elseif os(Linux)
        let os_nomatch = REG_NOMATCH.rawValue
        #endif

        if result == os_nomatch { return nil }
        if result != 0 {
            throw RegexError(fromRegDiagnostic: result)
        }
        var swiftMatches: [Match?] = []
        for m in matches [1..<matches.count]{
            let swiftMatch = Match(regmatch: m, underlyingString: entireString, offset: prefixSize)
            swiftMatches.append(swiftMatch)
        }
        return FindResult(entireMatch: Match(regmatch: matches[0], underlyingString: entireString, offset: prefixSize)!, groups: swiftMatches)
    }
    ///Finds the first match in the given string.
    public func findFirst(inString string: String) throws -> FindResult?   {
        return try findFirst(inString: string, prefixSize: 0, entireString: string)
    }

    /// Find all matches in the sequence.
    /// - attention: Iterating over the return value **consumes** results.
    /// - complexity: Results are found lazily.  Calling this function does not actually find anything: we perform the find later when you loop over the result.  This is because if you stop iterating after the first N matches you don't pay the cost to find them all.
    /// ... *However*. iterating over results *consumes* them, which may be unexpected.
    /// If you need to iterate over these results several times, pass the return value to an `Array` constructor.  Then we will find all the results right away and place them into the array where you can work with them at your leisure.
    public func findAll(inString string: String) -> FindResultSequence {
        return FindResultSequence(regex: self, string: string)
    }

    /// Replace all matches of a string by using a closure.  
    /// This allows powerful searching without the need to do advanced string edit logic by hand.
    /// - parameter string: The string in which to search.
    /// - parameter closure: A closure that will be passed `FindResult`s.  Return the desired replacement value for each FindResult.
    public func replaceAll(inString string: String, usingClosure closure: (FindResult) throws -> String) rethrows -> String {
        var replaced = string
        //For substitiutions of a different length than the source string, the string will change size as we read it
        var offset = 0
        for match in self.findAll(inString: string) {
            //find existing length
            let length = match.entireMatch.end - match.entireMatch.start

            //take the part up the current match
            var new_newString = String(replaced.utf8[replaced.utf8.startIndex ..< replaced.utf8.index(replaced.utf8.startIndex, offsetBy: match.entireMatch.start + offset)])!
            //take the new part
            let newString = try closure(match)
            new_newString += newString
            //take the part after the current match
            new_newString += String(replaced.utf8[replaced.utf8.index(replaced.utf8.startIndex, offsetBy: match.entireMatch.end + offset) ..< replaced.utf8.endIndex])!
            //calculate the new offset
            offset += (length - newString.utf8.count)

            replaced = new_newString
        }
        return replaced
    }

    /// Replace all matches of a regex with another string
    /// - parameter string: We use the `entireMatch` of this value
    /// - parameter newString: We replace the `entireMatch` with this new value
    public func replaceAll(inString string: String, withNewString newString: String) -> String {
        return self.replaceAll(inString: string, usingClosure: {j in return newString})
    }

    /// Replace the first match with another string
    /// - parameter string: We use the `entireMatch` of this value
    /// - parameter newString: We replace the `entireMatch` with thew new value
    public func replaceFirst(inString string: String, withNewString newString: String) -> String {
        var replaced = string
        if let match = try! self.findFirst(inString: string) {
            //take the part up the current match
            var new_newString = String(replaced.utf8[replaced.utf8.startIndex ..< replaced.utf8.index(replaced.utf8.startIndex, offsetBy: match.entireMatch.start)])!
            //take the new part
            let newString = newString
            new_newString += newString
            //take the part after the current match
            new_newString += String(replaced.utf8[replaced.utf8.index(replaced.utf8.startIndex, offsetBy: match.entireMatch.end) ..< replaced.utf8.endIndex])!
            return new_newString
        }
        return replaced
    }
}
