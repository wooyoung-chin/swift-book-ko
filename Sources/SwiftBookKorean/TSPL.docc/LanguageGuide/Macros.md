# 매크로 (Macros)

매크로를 사용하여 컴파일 시에 코드를 생성할 수 있습니다.

매크로를 사용하면 소스 코드가 컴파일 시점에 변환되어, 직접 반복적인 코드를 적는 것을 피할 수 있습니다.
Swift는 컴파일을 시행할 때, 우선 코드 안의 모든 매크로를 전개한 뒤 평소처럼 코드를 빌드합니다.

![매크로 전개의 개요를 보여 주는 다이어그램. 왼쪽에는 Swift 코드가, 오른쪽에는 그 코드에 매크로에 의해 여러 줄이 추가된 모습이 표현됨.](macro-expansion)

매크로는 새로운 코드를 추가할 뿐, 절대로 존재하는 코드를 지우거나 변경하지 않습니다.

Swift 컴파일러는 원본 코드와 매크로 전개 후의 코드가 모두 올바른 Swift 문법을 따르는지 검사합니다.
마찬가지로 매크로에 인자로 전달된 값들과 매크로에 의해 생성된 코드 안의 값들 또한 올바른 타입이어야 합니다.
또한 매크로를 전개하는 도중에 매크로의 구현에서 에러가 발생하는 경우, 이는 컴파일 에러로 취급됩니다.
이러한 장치들은 매크로를 사용하는 코드를 보다 쉽게 논리적으로 이해할 수 있게 해 주고, 매크로를 잘못 사용하거나 잘못 구현하는 등의 문제를 쉽게 파악할 수 있게 해 줍니다.

Swift에는 다음과 같은 두 가지 종류의 매크로가 있습니다.

- *자립형 매크로 (freestanding macros)*: 코드 상에 홀로 나타날 수 있으며, 특정 선언문에 부속되는 형태가 아닙니다.
- *부속형 매크로 (attached macros)*: 선언문에 추가되어 그 선언문을 변경합니다.

자립형 매크로와 부속형 매크로는 호출하는 방법이 조금 다르지만, 둘 모두 같은 원리로 전개되며, 같은 방식으로 구현합니다. 이하의 내용에서는 각각의 매크로에 관해 보다 자세히 서술합니다.

## 자립형 매크로 (Freestanding Macros)

자립형 매크로는 매크로 이름 앞에 번호 기호(`#`)를 붙이고 그 뒤 소괄호 안에 인자를 작성하여 호출할 수 있습니다.
예를 들어

```swift
func myFunction() {
    print("Currently running \(#function)")
    #warning("Something's wrong")
}
```

첫 번째 줄에서 `#function`은 Swift 표준 라이브러리의 [`function()`][] 매크로를 호출합니다.
이 코드를 컴파일하면 Swift는 [`function()`][]의 구현을 호출하고, 그 구현은 `#function`을 현재 함수의 이름으로 대체합니다.
이 코드를 실행하여 `myFunction()`을 호출하면 "Currently running myFunction()"이 출력됩니다.
두 번째 줄에서 `#warning`은 Swift 표준 라이브러리의 [`warning(_:)`][] 매크로를 호출하여 작성자가 정의한 대로 컴파일 시에 경고를 표시합니다.

[`function()`]: https://developer.apple.com/documentation/swift/function()
[`warning(_:)`]: https://developer.apple.com/documentation/swift/warning(_:)

독립 매크로는 `#function`과 같이 값을 생성하거나, 혹은 `#warning`과 같이 컴파일 시에 동작을 수행할 수 있습니다.
<!-- SE-0397: or they can generate new declarations.  -->

## 부속형 매크로 (Attached Macros)

부속형 매크로는 매크로 이름 앞에 앳 기호(`@`)를 붙이고 그 뒤 괄호 안에 인자를 작성하여 호출할 수 있습니다.

선언문에 추가된 부속형 매크로는, 새로운 메서드를 정의하거나 특정 프로토콜에 대한 준수 표시를 추가하는 등 그 선언문에 코드를 추가할 수 있습니다.

예를 들어, 매크로를 사용하지 않는 다음 코드를 살펴봅시다.

```swift
struct SundaeToppings: OptionSet {
    let rawValue: Int
    static let nuts = SundaeToppings(rawValue: 1 << 0)
    static let cherry = SundaeToppings(rawValue: 1 << 1)
    static let fudge = SundaeToppings(rawValue: 1 << 2)
}
```

이 코드에서 `SundaeToppings` 안의 옵션들은 같은 방식의 초기화자 호출을 직접 반복하고 있습니다.
이러한 경우 새 옵션을 추가할 때 줄 끝에 잘못된 수를 입력하는 등의 실수를 하기 쉽습니다.

다음은 비슷한 코드를 매크로를 사용해 작성한 것입니다.

```swift
@OptionSet<Int>
struct SundaeToppings {
    private enum Options: Int {
        case nuts
        case cherry
        case fudge
    }
}
```

이 예시에서 `SundaeToppings`는 `@OptionSet` 매크로를 호출하고 있습니다.
이 매크로는 비공개 열거형 `Options`의 케이스들을 읽어들인 후 각각에 대해 상수를 정의하고, `SundaeToppings` 구조체에 [`OptionSet`][] 프로토콜 준수 표시를 추가합니다.

[`OptionSet`]: https://developer.apple.com/documentation/swift/optionset

<!--
When the @OptionSet macro comes back, change both links back:

[`@OptionSet`]: https://developer.apple.com/documentation/swift/optionset-swift.macro
[`OptionSet`]: https://developer.apple.com/documentation/swift/optionset-swift.protocol
-->

`@OptionSet`을 전개하면 코드가 어떻게 달라지는지 살펴봅시다. 이 코드는 작성자가 직접 적는 것이 아니며, Swift에게 매크로 전개를 명시적으로 요청하는 경우에만 볼 수 있습니다.

```swift
struct SundaeToppings {
    private enum Options: Int {
        case nuts
        case cherry
        case fudge
    }

    typealias RawValue = Int
    var rawValue: RawValue
    init() { self.rawValue = 0 }
    init(rawValue: RawValue) { self.rawValue = rawValue }
    static let nuts: Self = Self(rawValue: 1 << Options.nuts.rawValue)
    static let cherry: Self = Self(rawValue: 1 << Options.cherry.rawValue)
    static let fudge: Self = Self(rawValue: 1 << Options.fudge.rawValue)
}
extension SundaeToppings: OptionSet { }
```

비공개 열거형 `Options` 이후의 모든 코드는 `@OptionSet` 매크로로부터 생성된 것입니다.
매크로를 사용하여 정적 변수들을 생성하는 방식으로 `SundaeToppings`를 정의하는 것이 모든 것을 직접 작성하는 방식에 비해 읽기 쉽고 유지 관리하기 쉬움을 알 수 있습니다.

## 매크로 선언문 (Macro Declarations)

일반적으로 Swift 코드에서 함수나 타입과 같은 심볼을 구현할 때 별도의 선언문이 필요하지 않지만, 매크로의 경우에는 선언과 구현을 분리해야 합니다.
매크로의 선언문에 들어가는 정보로는 매크로의 이름과 인자 목록, 사용될 수 있는 장소, 생성되는 코드의 종류 등이 있습니다.
매크로의 구현에는 매크로를 전개한 Swift code를 생성하는 코드가 들어갑니다.

`macro` 키워드를 사용하면 매크로를 선언할 수 있습니다.
예를 들어, 다음은 앞선 예시에서 사용되었던 `@OptionSet` 매크로의 선언문의 일부입니다.

```swift
public macro OptionSet<RawType>() =
        #externalMacro(module: "SwiftMacros", type: "OptionSetMacro")
```

첫 번째 줄은 매크로의 이름과 인자를 명시하고 있습니다. 이름은 `OptionSet`이고, 인자는 받지 않습니다.
두 번째 줄은 Swift 표준 라이브러리의 [`externalMacro(module:type:)`][] 매크로를 사용하여 Swift에게 매크로의 구현이 어디에 있는지 알려 줍니다.
이 경우 `SwiftMacros` 모듈에 있는 `OptionSetMacro`라는 타입이 `@OptionSet` 매크로를 구현하고 있습니다.

[`externalMacro(module:type:)`]: https://developer.apple.com/documentation/swift/externalmacro(module:type:)

`OptionSet`은 부속형 매크로이므로 구조체나 클래스를 이름지을 때처럼 대문자 캐멀 케이스를 사용합니다.
자립형 매크로의 경우 변수나 함수를 이름지을 때처럼 소문자 캐멀 케이스를 사용합니다.

> 참고:
> 매크로는 항상 `public`으로 선언됩니다.
> 매크로를 선언하는 코드와 매크로를 사용하는 코드가 서로 다른 모듈에 있기 때문에, `public`이 아닌 매크로는 어느 곳에서도 사용할 수 없습니다.

매크로 선언문은 매크로의 *역할*을 정의합니다. 역할이란 소스 코드에서 매크로를 호출할 수 있는 위치와 매크로가 생성할 수 있는 코드의 종류를 말합니다.
모든 매크로는 하나 이상의 역할이 있어야 하며, 이는 매크로 선언문 시작 부분에 속성의 형태로 작성합니다.
`@OptionSet` 선언문에서 역할 속성을 지정하는 부분까지 표시하면 다음과 같습니다.

```swift
@attached(member)
@attached(extension, conformances: OptionSet)
public macro OptionSet<RawType>() =
        #externalMacro(module: "SwiftMacros", type: "OptionSetMacro")
```

이 선언문에서 `@attached` 속성이 두 번 등장하는데, 이들은 각각 하나의 역할을 나타냅니다.
`@attached(member)`는 이 매크로를 타입에 적용했을 때 그 타입에 새로운 멤버가 추가된다는 사실을 나타냅니다.
실제로 `@OptionSet` 매크로는 `OptionSet` 프로토콜에서 요구하는 `init(rawValue:)` 초기화자와 몇 가지 새로운 멤버를 추가합니다.
이어서 나오는 `@attached(extension, conformances: OptionSet)`은 `@OptionSet`이 `OptionSet` 프로토콜 준수 표시를 추가한다는 사실을 나타냅니다.
실제로 `@OptionSet` 매크로는 자신이 적용된 타입을 확장하여 `OptionSet` 프로토콜 준수 표시를 추가합니다.

독립 매크로의 경우, `@freestanding` 속성을 사용하여 역할을 지정할 수 있습니다.

```swift
@freestanding(expression)
public macro line<T: ExpressibleByIntegerLiteral>() -> T =
        /* ... location of the macro implementation... */
```

<!--
Elided the implementation of #line above
because it's a compiler built-in:

public macro line<T: ExpressibleByIntegerLiteral>() -> T = Builtin.LineMacro
-->

여기서 `#line` 매크로의 역할은 `expression`(표현식)입니다. 표현식 매크로는 값을 생성할 수도 있고, 컴파일 시에 경고를 생성하는 등의 동작을 수행할 수도 있습니다.

매크로 선언문은 매크로의 역할뿐만 아니라 매크로가 어떤 심볼을 생성하는 지에 대한 정보도 담을 수 있습니다.
매크로 선언문이 이름 목록을 제공하는 경우, 해당 이름을 사용하는 선언문만 생성한다는 것이 보장되어 생성된 코드를 이해하고 디버그하는 데 도움이 됩니다.
`@OptionSet`의 선언문을 모두 표시하면 다음과 같습니다.

```swift
@attached(member, names: named(RawValue), named(rawValue),
        named(`init`), arbitrary)
@attached(extension, conformances: OptionSet)
public macro OptionSet<RawType>() =
        #externalMacro(module: "SwiftMacros", type: "OptionSetMacro")
```

위 선언문에서 `@attached(member)` 매크로는 `names:` 레이블 뒤에 `@OptionSet` 매크로가 생성할 각 심볼을 인자로 표시하고 있습니다.
여기서 `@OptionSet`이 `RawValue`, `rawValue`, `init` 심볼을 생성한다는 사실은 매크로를 작성하는 시점에서 미리 알 수 있기 때문에, 이것들을 모두 선언문에 명시하는 것이 가능합니다.

이름 목록 다음에 명시된 `arbitrary`는, 매크로 사용 이전에 미리 알 수 없는 이름의 선언도 생성할 수 있음을 나타냅니다.
예컨대 `@OptionSet` 매크로를 위의 `SundaeToppings`에 적용하면, 열거형 케이스들에 대응하는 타입 프로퍼티 `nuts`, `cherry`, `fudge`가 생성됩니다.

모든 가능한 매크로 역할을 비롯해 더 자세한 정보는 <doc:Attributes>의 <doc:Attributes#attached>와 <doc:Attributes#freestanding>에 설명되어 있습니다.

## 매크로 전개 (Macro Expansion)

매크로를 사용하는 Swift 코드를 빌드하면, 컴파일러는 매크로의 구현을 호출하여 매크로를 전개합니다.

![매크로 전개의 네 단계를 보여 주는 다이어그램. 입력은 Swift 소스 코드이고, 그것이 코드의 구조를 나타내는 트리로 변환됨. 매크로 구현이 트리에 가지를 추가함고, 최종 결과는 코드가 추가된 Swift 소스.](macro-expansion-full)

Swift가 매크로를 전개하는 방식은 구체적으로 다음과 같습니다.

1. 컴파일러가 코드를 읽고, 그것의 구조를 메모리 내에 표현합니다.

1. 메모리 내 표현의 일부가 매크로 구현으로 넘어가고, 그곳에서 매크로가 전개됩니다.

1. 매크로를 호출하는 부분이 그것을 전개한 형태로 대체됩니다.

1. 전개된 코드를 이용해 컴파일러가 컴파일을 계속 진행합니다.

각 단계를 이해하기 위해 다음의 예시를 살펴봅시다.

```swift
let magicNumber = #fourCharacterCode("ABCD")
```

`#fourCharacterCode` 매크로는 네 글자 길이의 문자열을 받아, 문자들의 ASCII 값을 이어쓴 것에 대응하는 부호 없는 32비트 정수를 반환합니다.
이는 간결하고 디버거로 읽을 수 있어서, 이러한 정수를 사용해 데이터를 식별하는 파일 형식들이 있습니다.
어떻게 이 매크로를 구현하는지는 아래의 <doc:Macros#Implementing-a-Macro> 절에 나와 있습니다.

위 코드의 매크로를 전개하기 위해 컴파일러는 Swift 파일을 읽고, 해당 코드를 *추상 구문 트리* 혹은 AST라고 부르는 메모리 내 표현으로 변환합니다.
AST는 코드의 구조를 명시적으로 나타내어, 컴파일러나 매크로 구현과 같이 코드 구조를 다루는 코드를 작성하기 쉽게 해 줍니다.
다음은 위 코드에 대한 AST를 나타낸 것으로, 일부 디테일을 생략하여 조금 단순화한 것입니다.

![상수를 루트 요소로 하는 트리 다이어그램. 상수 아래에는 이름, 매직 넘버와 값이 있고, 여기서 값은 매크로 호출임. 매크로 호출 아래엔 매크로 이름 fourCharacterCode와 인자가 있는데, 인자는 문자열 리터럴 ABCD.](macro-ast-original)

위 다이어그램은 이 코드의 구조가 메모리에서 어떻게 표현되는지 보여 줍니다.
AST의 각 요소는 소스 코드의 특정 부분에 대응합니다.
"상수 선언문" AST 요소는 그 아래에 두 개의 자식 요소를 가지는데, 이는 상수 선언문의 두 부분인 이름과 값을 나타냅니다.
"매크로 호출" 요소는 매크로의 이름과 매크로에 전달되는 인자 목록을 나타내는 자식 요소들을 갖습니다.

이 AST를 구성하는 과정에서 컴파일러는 소스 코드가 유효한 Swift인지 확인합니다.
예를 들어, `#fourCharacterCode`는 하나의 인자를 받으며, 이는 문자열이어야 합니다.
정수 인자를 전달하려고 하거나 문자열 리터럴 끝의 따옴표(`"`)를 빠뜨리면, 이 시점에서 에러가 발생합니다.

컴파일러는 코드에서 매크로를 호출하는 곳을 찾아서 해당 매크로를 구현하는 외부 바이너리를 로드합니다.
각 매크로 호출에 대해 컴파일러는 AST의 일부를 해당 매크로의 구현에 전달합니다.
다음은 AST 안에서 전달되는 부분("부분 AST")을 표현한 것입니다.

![매크로 호출을 루트 요소로 하는 트리 다이어그램. 매크로 호출은 매크로 이름 fourCharacterCode와 매크로 인자를 자식으로 가짐. 인자는 문자열 리터럴 ABCD.](macro-ast-input)

`#fourCharacterCode` 매크로의 구현은 매크로를 전개할 때 이 부분 AST를 입력으로 읽습니다.
매크로의 구현은 입력으로 받은 부분 AST에만 작용하므로, 매크로는 앞뒤에 오는 코드에 무관하게 항상 같은 방식으로 전개됩니다.
이러한 제약은 매크로 전개를 이해하기 쉽게 하고, 변경되지 않은 매크로를 Swift가 다시 전개하는 대신 건너뛸 수 있게 하여 코드 빌드 속도를 향상시킵니다.

<!-- TODO TR: Confirm -->
Swift는 매크로 구현 코드가 할 수 있는 일을 제한함으로써, 매크로 작성자가 실수로 다른 입력을 읽는 것을 피하게 해 줍니다.

- 매크로 구현에 전달되는 AST는 매크로를 나타내는 AST 요소만 포함하며, 앞뒤에 오는 코드는 포함하지 않습니다.

- 매크로 구현은 파일 시스템이나 네트워크에 접근할 수 없도록 하는 샌드박스 환경에서 실행됩니다.

이러한 보호 장치에 더해, 매크로 작성자는 매크로의 입력 외부에 있는 것을 읽거나 수정하지 않을 책임이 있습니다.
예를 들어, 매크로의 전개는 현재 시각에 의존해서는 안 됩니다.

`#fourCharacterCode`의 구현은 전개한 코드를 포함하는 새로운 AST를 생성합니다.
다음은 해당 코드가 컴파일러에 반환하는 내용입니다.

![정수 리터럴 1145258561을 가진 트리 다이어그램.](macro-ast-output)

컴파일러는 전개된 코드를 받아서, AST 내의 매크로 요소를 전개된 코드에 해당하는 요소로 대체합니다.
매크로를 전개한 후 컴파일러는 프로그램이 여전히 문법적으로 올바른 Swift이고 모든 타입이 올바른지 다시 확인합니다.
그 결과로 평소와 같이 컴파일할 수 있는 AST가 완성됩니다.

![상수를 루트 요소로 하는 트리 다이어그램. 상수 아래에는 매직 넘버와 값이 있고, 값은 타입이 UInt32인 정수 리터럴 1145258561임.](macro-ast-result)

이 AST는 다음과 같은 Swift 코드에 대응합니다.

```swift
let magicNumber = 1145258561 as UInt32
```

이 예시에서는 입력 소스 코드에 매크로가 단 하나였지만, 실제 프로그램에서는 같은 매크로가 여러 번 등장하거나 서로 다른 매크로를 여러 번 호출할 수도 있습니다. 이 경우 컴파일러는 매크로를 한 번에 하나씩 전개합니다.

한 매크로가 다른 매크로 안에 등장하면, 바깥 매크로가 먼저 전개됩니다. 이로써 바깥 매크로는 안쪽 매크로가 전개되기 전에 안쪽 매크로를 변경할 수 있습니다.

<!-- OUTLINE

- TR: Is there any limit to nesting?
  TR: Is it valid to nest like this -- if so, anything to note about it?

  ```
  let something = #someMacro {
      struct A { }
      @someMacro struct B { }
  }
  ```

- Macro recursion is limited.
  One macro can call another,
  but a given macro can't directly or indirectly call itself.
  The result of macro expansion can include other macros,
  but it can't include a macro that uses this macro in its expansion
  or declare a new macro.
  (TR: Likely need to iterate on details here)
-->

## 매크로 구현하기 (Implementing a Macro)

매크로를 구현하려면, 매크로 전개를 수행하는 타입과 매크로를 선언하여 API로 노출하는 라이브러리의 두 가지 구성 요소를 만들어야 합니다.
이러한 부분들은 매크로를 사용하는 코드와 별도로 빌드되며, 매크로와 클라이언트를 함께 개발하는 경우에도 마찬가지입니다.
이는 매크로 구현이 매크로의 클라이언트를 빌드하는 과정의 일부로서 실행되기 때문입니다.

Swift Package Manager를 사용하여 새로운 매크로를 만들려면 `swift package init --type macro`를 실행합니다. 
이렇게 하면 매크로 구현과 선언을 위한 템플릿을 비롯한 여러 파일이 생성됩니다.

기존 프로젝트에 매크로를 추가하려면 `Package.swift` 파일의 시작 부분을 다음과 같이 수정합니다.

- `swift-tools-version` 주석에서 Swift 도구 버전을 5.9 이상으로 설정합니다.
- `CompilerPluginSupport` 모듈을 불러옵니다.
- `platforms` 목록에서 최소 배포 타깃을 macOS 10.15으로 지정합니다.

예시 `Package.swift` 파일은 다음과 같이 시작합니다.

```swift
// swift-tools-version: 5.9

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "MyPackage",
    platforms: [ .iOS(.v17), .macOS(.v13)],
    // ...
)
```

다음으로 기존 `Package.swift` 파일에 매크로 구현용 타깃과 매크로 라이브러리용 타깃을 추가합니다.
예컨대 프로젝트에 맞게 이름을 변경하여 다음과 같은 내용을 추가할 수 있습니다.

```swift
targets: [
    // Macro implementation that performs the source transformations.
    .macro(
        name: "MyProjectMacros",
        dependencies: [
            .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
        ]
    ),

    // Library that exposes a macro as part of its API.
    .target(name: "MyProject", dependencies: ["MyProjectMacros"]),
]
```

위 코드는 매크로의 구현을 담을 `MyProjectMacros`와 그 매크로를 사용할 수 있게 해 주는 `MyProject`의 두 가지 타깃을 정의하고 있습니다.

매크로의 구현은 [SwiftSyntax][] 모듈과 AST를 사용하여 Swift 코드와 체계적으로 상호 작용합니다.
Swift Package Manager로 새로운 매크로 패키지를 만든 경우, 생성된 `Package.swift` 파일은 자동적으로 SwiftSyntax에 의존합니다.
기존 프로젝트에 매크로를 추가하는 경우에는 `Package.swift` 파일에 SwiftSyntax에 대한 의존성을 추가해야 합니다.

[SwiftSyntax]: https://github.com/swiftlang/swift-syntax

```swift
dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "509.0.0")
],
```

매크로의 역할별로 그 구현이 준수해야 하는 SwiftSyntax 프로토콜이 있습니다.
예를 들어, 이전 절의 `#fourCharacterCode`를 살펴봅시다.
다음은 해당 매크로를 구현하는 구조체입니다.

```swift
import SwiftSyntax
import SwiftSyntaxMacros

public struct FourCharacterCode: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax {
        guard let argument = node.argumentList.first?.expression,
              let segments = argument.as(StringLiteralExprSyntax.self)?.segments,
              segments.count == 1,
              case .stringSegment(let literalSegment)? = segments.first
        else {
            throw CustomError.message("Need a static string")
        }

        let string = literalSegment.content.text
        guard let result = fourCharacterCode(for: string) else {
            throw CustomError.message("Invalid four-character code")
        }

        return "\(raw: result) as UInt32"
    }
}

private func fourCharacterCode(for characters: String) -> UInt32? {
    guard characters.count == 4 else { return nil }

    var result: UInt32 = 0
    for character in characters {
        result = result << 8
        guard let asciiValue = character.asciiValue else { return nil }
        result += UInt32(asciiValue)
    }
    return result
}
enum CustomError: Error { case message(String) }
```

기존 Swift Package Manager 프로젝트에 이 매크로를 추가하는 경우, 매크로 타깃의 진입점 역할을 하는 타입을 만들고 그 안에 해당 타깃이 정의하는 매크로들의 목록을 정의합니다.

```swift
import SwiftCompilerPlugin

@main
struct MyProjectMacros: CompilerPlugin {
    var providingMacros: [Macro.Type] = [FourCharacterCode.self]
}
```

`#fourCharacterCode` 매크로는 표현식을 생성하는 자립형 매크로이므로, 이를 구현하는 `FourCharacterCode` 타입은 `ExpressionMacro` 프로토콜을 준수합니다.
`ExpressionMacro` 프로토콜에는 AST를 전개하는 `expansion(of:in:)` 메서드라는 하나의 요구 사항이 있습니다.
매크로 역할과 해당하는 SwiftSyntax 프로토콜의 목록은 <doc:Attributes>의 <doc:Attributes#attached>와 <doc:Attributes#freestanding>에 설명되어 있습니다.

`#fourCharacterCode` 매크로를 전개하기 위해 Swift는 이 매크로를 사용하는 코드의 AST를 매크로 구현이 포함된 라이브러리에 전송합니다.
라이브러리 안에서 Swift는 `FourCharacterCode.expansion(of:in:)`을 호출하며 이 떄 AST와 컨텍스트를 메서드의 인자로 전달합니다.
`expansion(of:in:)`의 구현은 `#fourCharacterCode`에 인자로 전달된 문자열을 찾고 해당하는 32비트 부호 없는 정수 리터럴 값을 계산합니다.

위 예제에서 첫 번째 `guard` 블록은 AST에서 문자열 리터럴을 추출하여 해당 AST 요소를 `literalSegment`에 할당합니다.
두 번째 `guard` 블록은 비공개 `fourCharacterCode(for:)` 함수를 호출합니다.
매크로가 잘못 사용된 경우 이 두 블록 모두 에러를 던지고, 그 에러 메시지는 매크로를 잘못 호출한 지점에서 컴파일 에러가 됩니다
예를 들어, 매크로를 `#fourCharacterCode("AB" + "CD")`로 호출하려고 하면 컴파일러는 "Need a static string" 에러를 표시합니다.

`expansion(of:in:)` 메서드는 AST에서 표현식을 나타내는 SwiftSyntax의 타입인 `ExprSyntax`의 인스턴스를 반환합니다.
이 타입은 `StringLiteralConvertible` 프로토콜을 준수하므로, 위 예시에서처럼 매크로 구현이 간단하게 문자열을 반환하는 것이 가능합니다.
매크로 구현이 반환해야 하는 SwiftSyntax 타입은 모두 `StringLiteralConvertible`을 준수하므로, 어떤 매크로를 구현하더라도 같은 방식을 사용할 수 있습니다.

<!-- TODO contrast the `\(raw:)` and non-raw version.  -->

<!--
The return-a-string APIs come from here

https://github.com/swiftlang/swift-syntax/blob/main/Sources/SwiftSyntaxBuilder/Syntax%2BStringInterpolation.swift
-->

<!-- OUTLINE:

- Note:
  Behind the scenes, Swift serializes and deserializes the AST,
  to pass the data across process boundaries,
  but your macro implementation doesn't need to deal with any of that.

- This method is also passed a macro-expansion context, which you use to:

    + Generate unique symbol names
    + Produce diagnostics (`Diagnostic` and `SimpleDiagnosticMessage`)
    + Find a node's location in source

- Macro expansion happens in their surrounding context.
  A macro can affect that environment if it needs to ---
  and a macro that has bugs can interfere with that environment.
  (Give guidance on when you'd do this.  It should be rare.)

- Generated symbol names let a macro
  avoid accidentally interacting with symbols in that environment.
  To generate a unique symbol name,
  call the `MacroExpansionContext.makeUniqueName()` method.

- Ways to create a syntax node include
  Making an instance of the `Syntax` struct,
  or `SyntaxToken`
  or `ExprSyntax`.
  (Need to give folks some general ideas,
  and enough guidance so they can sort through
  all the various `SwiftSyntax` node types and find the right one.)

- Attached macros follow the same general model as expression macros,
  but with more moving parts.

- Pick the subprotocol of `AttachedMacro` to conform to,
  depending on which kind of attached macro you're making.
  [This is probably a table]

  + `AccessorMacro` goes with `@attached(accessor)`
  + `ConformanceMacro` goes with `@attached(conformance)`
    [missing from the list under Declaring a Macro]
  + `MemberMacro` goes with `@attached(member)`
  + `PeerMacro` goes with `@attached(peer)`
  + `MemberAttributeMacro` goes with `@member(memberAttribute)`

- Code example of conforming to `MemberMacro`.

  ```
  static func expansion<
    Declaration: DeclGroupSyntax,
    Context: MacroExpansionContext
  >(
    of node: AttributeSyntax,
    providingMembersOf declaration: Declaration,
    in context: Context
  ) throws -> [DeclSyntax]
  ```

- Adding a new member by making an instance of `Declaration`,
  and returning it as part of the `[DeclSyntax]` list.

-->

## 매크로 개발 및 디버그하기 (Developing and Debugging Macros)

매크로는 외부 상태에 의존하지 않고 외부 상태를 변경하지도 않으면서 하나의 AST를 다른 AST로 변환하기에, 테스트를 이용하여 개발하기에 적합합니다.
또한 문자열 리터럴로 구문 노드를 만들 수 있어, 간단하게 테스트의 입력값을 설정할 수 있습니다.
그리고 AST의 `description` 프로퍼티를 읽어서 예상 값과 비교할 문자열을 얻을 수도 있습니다.
예를 들어, 다음은 이전 섹션의 `#fourCharacterCode` 매크로를 테스트하는 코드입니다.

```swift
let source: SourceFileSyntax =
    """
    let abcd = #fourCharacterCode("ABCD")
    """

let file = BasicMacroExpansionContext.KnownSourceFile(
    moduleName: "MyModule",
    fullFilePath: "test.swift"
)

let context = BasicMacroExpansionContext(sourceFiles: [source: file])

let transformedSF = source.expand(
    macros:["fourCharacterCode": FourCharacterCode.self],
    in: context
)

let expectedDescription =
    """
    let abcd = 1145258561 as UInt32
    """

precondition(transformedSF.description == expectedDescription)
```

위 예시는 전제 조건을 사용하여 매크로를 테스트하지만, 대신 테스트 프레임워크를 사용할 수도 있습니다.

<!-- OUTLINE:

- Ways to view the macro expansion while debugging.
  The SE prototype provides `-Xfrontend -dump-macro-expansions` for this.
  [TR: Is this flag what we should suggest folks use,
  or will there be better command-line options coming?]

- Use diagnostics for macros that have constraints/requirements
  so your code can give a meaningful error to users when those aren't met,
  instead of letting the compiler try & fail to build the generated code.

Additional APIs and concepts to introduce in the future,
in no particular order:

- Using `SyntaxRewriter` and the visitor pattern for modifying the AST

- Adding a suggested correction using `FixIt`

- concept of trivia

- `TokenSyntax`
-->

> 베타 소프트웨어:
>
> 이 도큐멘테이션은 개발중인 API 혹은 기술에 관한 예비 정보를 담고 있습니다. 이 정보는 바뀔 수 있으며, 이 도큐멘테이션에 따라 구현된 소프트웨어는 최종 운영 체제 소프트웨어를 이용해 테스트되어야 합니다.
>
>  [Apple 베타 소프트웨어](https://developer.apple.com/support/beta-software/) 사용에 관해 더 알아보기.

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
-->
