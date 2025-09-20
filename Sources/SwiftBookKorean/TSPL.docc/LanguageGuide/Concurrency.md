# 동시성 (Concurrency)

비동기 연산을 수행합니다.

Swift는 비동기 및 병렬 코드 작성 지원을 탑재하고 있습니다.
*비동기 코드 (Asynchronous code)* 는 일시 정지된 후 나중에 재개될 수 있습니다.
다만 코드의 여러 부분이 동시에 실행되지는 않습니다.
코드를 일시 정지한 후 재개함으로써, 네트워크로부터 데이터를 불러오거나 파일을 파싱하는 등의 오래 지속되는 연산을 수행하는 도중에
UI를 업데이트하는 등의 단기적 연산을 이어나갈 수 있습니다.
*병렬 코드 (Parallel code)* 란 여러 코드가 동시에 실행되는 것을 가리킵니다.
예를 들어, 4코어 프로세서를 탑재한 컴퓨터는 코어 하나당 한 가지 작업을 수행함으로써 동시에 네 가지 코드를 실행할 수 있습니다.
병렬 혹은 비동기 코드를 사용하는 프로그램은 여러 연산을 한 번에 수행하고, 외부 시스템을 기다리는 중인 연산을 일시 정지할 수 있습니다.
이러한 흔히 나타나는 비동기와 병렬 코드의 결합을 가리킬 때 이 장의 나머지에서는 *동시성* 이라는 용어를 사용합니다.

병렬 혹은 비동기 코드로 얻는 스케줄링 유연성에는 복잡성 증가라는 대가가 따릅니다.
동시성 코드를 작성할 때 우리는 어떤 코드가 동시에 실행될지 혹은 어떤 순서로 코드가 실행될지 미리 알 수 없습니다.
동시성 코드에서 흔한 문제 중 하나는
여러 코드가 한 가지 가변 상태에 동시에 접근하려고 할 때 발생하는데,
이를 *데이터 경합 (data race)* 이라고 합니다.
언어 수준의 동시성 지원을 사용하면
Swift가 데이터 경합을 감지하고 방지하며,
대부분의 데이터 경합은 컴파일 시 에러를 발생시키게 됩니다.
일부 데이터 경합은 코드가 실행될 때까지 감지되지 않으며,
이러한 데이터 경합은 코드 실행을 종료시킵니다.
이 장에서 설명할 액터와 격리를 사용하여 데이터 경합을 방지할 수 있습니다.

> 참고: 이전에 동시성 코드를 작성해본 적이 있다면,
> 스레드를 사용하는 것에 익숙할 것입니다.
> Swift의 동시성 모델은 스레드 위에 구축되었지만,
> 직접적으로 스레드와 상호작용하지는 않습니다.
> Swift의 비동기 함수는
> 실행 중인 스레드를 포기할 수 있으며,
> 이를 통해 한 가지 함수가 차단되어 있는 동안
> 다른 비동기 함수가 해당 스레드에서 실행될 수 있습니다.
> 비동기 함수가 재개될 때,
> Swift는 해당 함수가 어떤 스레드에서 실행될지에 대해
> 어떤 보장도 하지 않습니다.

Swift의 언어 지원을 사용하지 않고 동시성 코드를 작성하는 것도 가능하지만,
그러한 코드는 읽기 어려운 경향이 있습니다.
예를 들어, 다음 코드는 사진 이름 목록을 다운로드하고,
해당 목록의 첫 번째 사진을 다운로드한 다음,
그 사진을 사용자에게 보여줍니다.

```swift
listPhotos(inGallery: "Summer Vacation") { photoNames in
    let sortedNames = photoNames.sorted()
    let name = sortedNames[0]
    downloadPhoto(named: name) { photo in
        show(photo)
    }
}
```

<!--
  - test: `async-via-nested-completion-handlers`

  ```swifttest
  >> struct Data {}  // Instead of actually importing Foundation
  >> func listPhotos(inGallery name: String, completionHandler: ([String]) -> Void ) {
  >>   completionHandler(["IMG001", "IMG99", "IMG0404"])
  >> }
  >> func downloadPhoto(named name: String, completionHandler: (Data) -> Void) {
  >>     completionHandler(Data())
  >> }
  >> func show(_ image: Data) { }
  -> listPhotos(inGallery: "Summer Vacation") { photoNames in
         let sortedNames = photoNames.sorted()
         let name = sortedNames[0]
         downloadPhoto(named: name) { photo in
             show(photo)
         }
     }
  ```
-->

이러한 간단한 경우에서도 코드를 일련의 완료 핸들러로 작성해야 하기 때문에 중첩된 클로저가 필요하게 됩니다.
이 스타일로는 조금만 더 코드가 복잡해지고 깊게 중첩되더라도 순식간에 다루기 어려워집니다.

## 비동기 함수 정의하고 호출하기 (Defining and Calling Asynchronous Functions)

*비동기 함수 (asynchronous function)* 또는 *비동기 메서드 (asynchronous method)* 는
실행 도중에 일시 정지될 수 있는 특별한 종류의 함수나 메서드입니다.
이는 완료될 때까지 실행되거나, 에러를 던지거나, 아예 반환하지 않는
일반적인 동기 함수 및 메서드와 비교됩니다.
비동기 함수나 메서드도 여전히 이 세 가지 중 하나의 동작을 수행하지만,
무언가를 기다리는 중간에 멈출 수 있다는 점이 다릅니다.
비동기 함수나 메서드의 본문에서는
실행이 일시 정지될 수 있는 각 지점을 표시해야 합니다.

함수나 메서드가 비동기임을 나타내려면
선언 시 매개변수 뒤에 `async` 키워드를 작성하면 됩니다.
이는 에러를 던지는 함수를 표시하기 위해 `throws`를 사용하는 방식과 유사합니다.
함수나 메서드가 값을 반환한다면
반환 화살표(`->`) 앞에 `async`를 작성합니다.
예를 들어,
다음은 갤러리에 있는 사진들의 이름을 가져오는 방법입니다.

```swift
func listPhotos(inGallery name: String) async -> [String] {
    let result = // ... some asynchronous networking code ...
    return result
}
```

<!--
  - test: `async-function-shape`

  ```swifttest
  -> func listPhotos(inGallery name: String) async -> [String] {
         let result = // ... some asynchronous networking code ...
  >>     ["IMG001", "IMG99", "IMG0404"]
         return result
     }
  ```
-->

비동기이면서 동시에 에러를 던지는 함수나 메서드의 경우,
`async`를 `throws` 앞에 작성합니다.

<!--
  - test: `async-comes-before-throws`

  ```swifttest
  >> func right() async throws -> Int { return 12 }
  >> func wrong() throws async -> Int { return 12 }
  !$ error: 'async' must precede 'throws'
  !! func wrong() throws async -> Int { return 12 }
  !! ^~~~~~
  !! async
  ```
-->

비동기 메서드를 호출할 때는
해당 메서드가 반환될 때까지 실행이 일시 정지됩니다.
호출 앞에 `await`를 적어
일시 정지 가능 지점을 표시하는데,
이는 에러를 던지는 함수를 호출할 때 앞에 `try`를 적어
에러가 발생할 경우 실행 흐름이 바뀔 수 있음을 표시하는 것과 같습니다.
비동기 메서드 안에서 실행 흐름이 일시 정지될 수 있는 것은 *다른 비동기 메서드를 호출할 때 뿐* 입니다.
코드의 일시 정지는 항상 사전에 명시되어야 하고, 이를 위해 모든 가능한 일시 정지 지점에 `await` 표시를 해야 합니다.
이렇게 코드가 일시 정지할 수 있는 지점을 모두 표시함으로써
동시성 코드를 더 읽기 쉽고 이해하기 쉽게 할 수 있습니다.

예를 들어,
다음 코드는 갤러리에 있는 모든 사진의 이름을 가져온 다음
첫 번째 사진을 보여줍니다.

```swift
let photoNames = await listPhotos(inGallery: "Summer Vacation")
let sortedNames = photoNames.sorted()
let name = sortedNames[0]
let photo = await downloadPhoto(named: name)
show(photo)
```

<!--
  - test: `defining-async-function`

  ```swifttest
  >> struct Data {}  // Instead of actually importing Foundation
  >> func downloadPhoto(named name: String) async -> Data { return Data() }
  >> func show(_ image: Data) { }
  >> func listPhotos(inGallery name: String) async -> [String] {
  >>     return ["IMG001", "IMG99", "IMG0404"]
  >> }
  >> func f() async {
  -> let photoNames = await listPhotos(inGallery: "Summer Vacation")
  -> let sortedNames = photoNames.sorted()
  -> let name = sortedNames[0]
  -> let photo = await downloadPhoto(named: name)
  -> show(photo)
  >> }
  ```
-->

`listPhotos(inGallery:)`와 `downloadPhoto(named:)` 함수는
모두 네트워크 요청을 해야 하므로
완료되는 데 상당한 시간이 걸릴 수 있습니다.
반환 화살표 앞에 `async`를 적어 두 함수를 모두 비동기로 만들면
이 코드가 사진이 준비되기를 기다리는 동안
앱의 나머지 코드가 계속 실행될 수 있습니다.

위 예시의 동시성을 이해하기 위해 한 가지 가능한 실행 순서를 살펴봅시다.

1. 코드는 첫 번째 줄부터 실행을 시작하여
   첫 번째 `await`까지 실행됩니다.
   `listPhotos(inGallery:)` 함수를 호출하고
   해당 함수가 반환되기를 기다리는 동안 실행을 일시 정지합니다.

2. 이 코드의 실행이 일시 정지되는 동안
   같은 프로그램의 다른 동시성 코드가 실행됩니다.
   예를 들어, 오래 실행되는 백그라운드 작업이
   새로운 사진 갤러리 목록을 계속 업데이트할 수 있습니다.
   그 코드 역시 `await`로 표시된 다음 일시 정지 지점까지 실행되거나
   완료될 때까지 실행됩니다.

3. `listPhotos(inGallery:)`가 반환된 후
   이 코드는 해당 지점부터 실행을 계속합니다.
   반환된 값을 `photoNames`에 할당합니다.

4. `sortedNames`와 `name`을 정의하는 줄들은
   일반적인 동기 코드입니다.
   이 줄들에는 `await`로 표시된 것이 없으므로
   일시 정지 가능 지점이 없습니다.

5. 다음으로 `await`가 나오는 것은 `downloadPhoto(named:)` 함수 호출에서입니다.
   이 코드는 해당 함수가 반환될 때까지 다시 실행을 일시 정지하며,
   다른 동시성 코드가 실행될 기회를 제공합니다.

6. `downloadPhoto(named:)`가 반환된 후
   반환 값이 `photo`에 할당되고
   `show(_:)`를 호출할 때 인자로 전달됩니다.

코드에서 `await`로 표시된 일시 정지 가능 지점들은
비동기 함수나 메서드가 반환되기를 기다리는 동안
현재 코드가 실행을 잠시 멈출 수 있음을 나타냅니다.
이를 *스레드 양보 (yielding the thread)* 라고도 하는데,
내부적으로 Swift가 현재 스레드에서 코드 실행을 일시 정지하고
대신 그 스레드에서 다른 코드를 실행하기 때문입니다. 
`await` 코드는 실행을 일시 정지할 수 있어야 하므로,
프로그램에서 비동기 함수나 메서드를 호출할 수 있는 곳은 다음의 장소로 제한됩니다.

- 비동기 함수, 메서드 또는 프로퍼티의 본문 내부 코드

- `@main`으로 표시된 구조체, 클래스 또는 열거형의
  정적 `main()` 메서드 내부 코드

- 아래 <doc:Concurrency#Unstructured-Concurrency>에서 보여주는
  비구조화된 자식 작업 내부 코드

<!--
  SE-0296 specifically calls out that top-level code is *not* an async context,
  contrary to what you might expect.
  If that gets changed, add this bullet to the list above:

  - Code at the top level that forms an implicit main function.
-->

[`Task.sleep(for:tolerance:clock:)`][] 메서드를 이용해 간단한 코드를 적어 보면
동시성이 어떻게 작동하는지 이해하는 데 도움이 됩니다.
이 메서드는 최소한 주어진 시간 동안 현재 작업을 일시 정지시키는데,
다음은 `sleep(for:tolerance:clock:)`을 사용하여
네트워크 연산 대기를 시뮬레이션하도록 `listPhotos(inGallery:)`를 구현한 예입니다.

[`Task.sleep(for:tolerance:clock:)`]: https://developer.apple.com/documentation/swift/task/sleep(for:tolerance:clock:)

```swift
func listPhotos(inGallery name: String) async throws -> [String] {
    try await Task.sleep(for: .seconds(2))
    return ["IMG001", "IMG99", "IMG0404"]
}
```

<!--
  - test: `sleep-in-toy-code`

  ```swifttest
  >> struct Data {}  // Instead of actually importing Foundation
  -> func listPhotos(inGallery name: String) async throws -> [String] {
         try await Task.sleep(for: .seconds(2))
         return ["IMG001", "IMG99", "IMG0404"]
  }
  ```
-->

이렇게 구현된 `listPhotos(inGallery:)`는
`Task.sleep(until:tolerance:clock:)` 호출이 에러를 던질 수 있으므로
비동기이면서 동시에 에러를 던지는 함수입니다.
이 `listPhotos(inGallery:)`를 호출할 때는
`try`와 `await`를 모두 작성합니다.

```swift
let photos = try await listPhotos(inGallery: "A Rainy Weekend")
```

비동기 함수는 에러를 던지는 함수와 몇 가지 유사점이 있습니다.
비동기 함수나 에러를 던지는 함수를 정의할 때는
`async`나 `throws`로 표시하고,
그러한 함수를 호출할 때는 `await`나 `try`로 표시합니다.
비동기 함수는 다른 비동기 함수를 호출할 수 있으며,
이는 에러를 던지는 함수가 다른 에러를 던지는 함수를 호출할 수 있는 것과 같습니다.

다만 한 가지 아주 중요한 차이점이 있습니다.
에러를 던지는 코드는 `do`-`catch` 블록으로 감싸서 에러를 처리하거나
`Result`를 사용하여 에러를 저장해 다른 곳의 코드가 처리하도록 할 수 있습니다.
이러한 접근 방식을 통해 다음의 예시에서와 같이 에러를 던지지 않는 코드에서
에러를 던지는 함수를 호출할 수 있습니다.

```swift
func availableRainyWeekendPhotos() -> Result<[String], Error> {
    return Result {
        try listDownloadedPhotos(inGallery: "A Rainy Weekend")
    }
}
```

반면에 비동기 코드를 감싸서
동기 코드에서 호출하고 결과를 기다릴 수 있는 안전한 방법은 없습니다.
Swift 표준 라이브러리는 의도적으로 이러한 안전하지 않은 기능을 제공하지 않습니다.
이것을 직접 구현하려고 하면 복잡한 경합, 스레딩 문제, 교착과 같은 문제로 이어질 수 있습니다.
기존 프로젝트에 동시성 코드를 추가할 때는 위에서 아래로 (top down) 작업하는 것이 좋습니다.
예컨대, 코드의 최상위 계층부터 동시성을 사용하도록 변환한 다음
그것이 호출하는 함수와 메서드를 변환하기 시작하여
프로젝트 아키텍처를 한 번에 한 계층씩 작업해 나갈 수 있습니다.
동기 코드는 비동기 코드를 호출할 수 없기 때문에
아래에서 위로 향하는 (bottom-up) 접근법은 취할 수 없습니다.

<!--
  OUTLINE

  ## Asynchronous Closures

  like how you can have an async function, a closure con be async
  if a closure contains 'await' that implicitly makes it async
  you can mark it explicitly with "async -> in"

  (discussion of @MainActor closures can probably go here too)
-->

## 비동기 시퀀스 (Asynchronous Sequences)

앞 절의 `listPhotos(inGallery:)` 함수는
배열의 모든 요소가 준비된 후
전체 배열을 한 번에 비동기적으로 반환합니다.
다른 접근법으로는 *비동기 시퀀스 (asynchronous sequence)* 를 사용하여
컬렉션의 요소를 한 번에 하나씩 기다리는 방법이 있습니다.
비동기 시퀀스 위에서 반복문을 사용하는 모습을 살펴봅시다.

```swift
import Foundation

let handle = FileHandle.standardInput
for try await line in handle.bytes.lines {
    print(line)
}
```

<!--
  - test: `async-sequence`

  ```swifttest
  -> import Foundation

  >> func f() async throws {
  -> let handle = FileHandle.standardInput
  -> for try await line in handle.bytes.lines {
         print(line)
     }
  >> }
  ```
-->

위 예시는 일반적인 `for`-`in` 반복문 대신
`for` 뒤에 `await`를 적었습니다.
비동기 함수나 메서드를 호출할 때와 마찬가지로
`await`를 적는 것은 일시 정지 가능 지점을 나타냅니다.
`for`-`await`-`in` 반복문은
다음 요소가 사용 가능해지기를 기다릴 때
각 반복의 시작 부분에서 실행을 일시 정지할 수 있습니다.

[`Sequence`][] 프로토콜 준수 표시를 추가하여
`for`-`in` 반복문에서 자신만의 타입을 사용할 수 있는 것과 같은 방식으로,
[`AsyncSequence`][] 프로토콜 준수 표시를 추가하면
`for`-`await`-`in` 반복문에서 자신만의 타입을 사용할 수 있습니다.

[`Sequence`]: https://developer.apple.com/documentation/swift/sequence
[`AsyncSequence`]: https://developer.apple.com/documentation/swift/asyncsequence

<!--
  TODO what happened to ``Series`` which was supposed to be a currency type?
  Is that coming from Combine instead of the stdlib maybe?

  Also... need a real API that produces a async sequence.
  I'd prefer not to go through the whole process of making one here,
  since the protocol reference has enough detail to show you how to do that.
  There's nothing in the stdlib except for the AsyncFooSequence types.
  Maybe one of the other conforming types from an Apple framework --
  how about FileHandle.AsyncBytes (myFilehandle.bytes.lines) from Foundation?

  https://developer.apple.com/documentation/swift/asyncsequence
  https://developer.apple.com/documentation/foundation/filehandle

  if we get a stdlib-provided async sequence type at some point,
  rewrite the above to fit the same narrative flow
  using something like the following

  let names = await listPhotos(inGallery: "Winter Vacation")
  for await photo in Photos(names: names) {
      show(photo)
  }
-->

## 비동기 함수를 병렬로 호출하기 (Calling Asynchronous Functions in Parallel)

`await`와 함께 비동기 함수를 호출하면
한 번에 하나의 코드만 실행됩니다.
비동기 코드가 실행되는 동안
호출자는 해당 코드가 완료되기를 기다린 후
다음 줄의 코드를 실행합니다.
예컨대 갤러리에서 처음 세 장의 사진을 가져오려면
다음과 같이 `downloadPhoto(named:)` 함수에 대한 세 번의 호출을 기다릴 수 있습니다.

```swift
let firstPhoto = await downloadPhoto(named: photoNames[0])
let secondPhoto = await downloadPhoto(named: photoNames[1])
let thirdPhoto = await downloadPhoto(named: photoNames[2])

let photos = [firstPhoto, secondPhoto, thirdPhoto]
show(photos)
```

<!--
  - test: `defining-async-function`

  ```swifttest
  >> func show(_ images: [Data]) { }
  >> func ff() async {
  >> let photoNames = ["IMG001", "IMG99", "IMG0404"]
  -> let firstPhoto = await downloadPhoto(named: photoNames[0])
  -> let secondPhoto = await downloadPhoto(named: photoNames[1])
  -> let thirdPhoto = await downloadPhoto(named: photoNames[2])

  -> let photos = [firstPhoto, secondPhoto, thirdPhoto]
  -> show(photos)
  >> }
  ```
-->

이 접근에는 한 가지 문제점이 있습니다.
다운로드가 비동기적으로 진행되어 다른 작업을 동시에 실행할 수 있는 것은 맞지만,
`downloadPhoto(named:)` 호출 자체는 한 번에 하나씩만 실행됩니다.
즉, 한 사진의 다운로드가 끝나야 다음 사진의 다운로드가 시작됩니다.
하지만 이 연산들이 서로를 기다릴 필요는 없습니다.
각 사진은 독립적으로, 심지어는 동시에 다운로드될 수 있습니다.

비동기 함수를 호출하여 주변 코드와 병렬로 실행되도록 하려면
상수를 정의할 때 `let` 앞에 `async`를 적고,
상수를 사용할 때마다 `await`를 적으면 됩니다.

```swift
async let firstPhoto = downloadPhoto(named: photoNames[0])
async let secondPhoto = downloadPhoto(named: photoNames[1])
async let thirdPhoto = downloadPhoto(named: photoNames[2])

let photos = await [firstPhoto, secondPhoto, thirdPhoto]
show(photos)
```

<!--
  - test: `calling-with-async-let`

  ```swifttest
  >> struct Data {}  // Instead of actually importing Foundation
  >> func show(_ images: [Data]) { }
  >> func downloadPhoto(named name: String) async -> Data { return Data() }
  >> let photoNames = ["IMG001", "IMG99", "IMG0404"]
  >> func f() async {
  -> async let firstPhoto = downloadPhoto(named: photoNames[0])
  -> async let secondPhoto = downloadPhoto(named: photoNames[1])
  -> async let thirdPhoto = downloadPhoto(named: photoNames[2])

  -> let photos = await [firstPhoto, secondPhoto, thirdPhoto]
  -> show(photos)
  >> }
  ```
-->

이 예시에서는
세 번의 `downloadPhoto(named:)` 호출이 모두
이전 호출이 완료되기를 기다리지 않고 시작됩니다.
시스템 리소스가 충분하다면 동시에 실행될 수 있습니다.
이러한 함수 호출들은 `await`로 표시되지 않았는데
코드가 함수의 결과를 기다리기 위해 일시 정지하지 않기 때문입니다.
대신 `photos`가 정의되는 줄까지 실행이 계속되고,
그 지점에서 프로그램은 이러한 비동기 호출들의 결과가 필요하므로
`await`를 적어서 세 장의 사진 다운로드가 모두 완료될 때까지
실행을 일시 정지합니다.

다음은 이 두 접근법의 차이점을 생각해 볼 수 있는 방법입니다.

- 다음 줄의 코드가 해당 함수의 결과에 의존할 때는
  `await`와 함께 비동기 함수를 호출합니다.
  이는 순차적으로 수행되는 작업을 만듭니다.
- 나중까지 결과물이 필요하지 않을 때는
  `async`-`let`으로 비동기 함수를 호출합니다.
  이는 병렬로 수행될 수 있는 작업을 만듭니다.
- `await`와 `async`-`let` 모두
  자신이 일시 정지된 동안 다른 코드가 실행될 수 있도록 합니다.
- 두 경우 모두 `await`로 일시 정지 가능 지점을 표시하여
  비동기 함수가 반환될 때까지 필요하다면 실행이 일시 정지됨을 나타냅니다.

같은 코드에서 이 두 접근법을 함께 사용할 수도 있습니다.

## 작업과 작업 그룹 (Tasks and Task Groups)

*작업 (task)* 은 프로그램의 일부로, 비동기적으로 실행될 수 있는 일의 단위입니다.
모든 비동기 코드는 어떤 작업의 일부로 실행됩니다.
작업 자체는 한 번에 하나의 일만 수행하지만,
여러 작업을 생성하면 Swift가 이들을 동시에 실행하도록 스케줄링할 수 있습니다.

앞 절에서 설명한 `async`-`let` 문법은
암묵적으로 자식 작업을 생성합니다.
이 문법은 프로그램이 실행해야 할 작업을 이미 알고 있을 때 잘 작동합니다.
작업 그룹([`TaskGroup`][]의 인스턴스)을 생성하고
명시적으로 자식 작업을 해당 그룹에 추가할 수도 있는데,
이렇게 하면 우선 순위와 취소에 대한 더 많은 제어권을 얻고
동적인 수의 작업을 생성할 수 있습니다.

[`TaskGroup`]: https://developer.apple.com/documentation/swift/taskgroup

작업들은 계층적으로 배열됩니다.
주어진 작업 그룹의 각 작업은 동일한 부모 작업을 가지며,
각 작업은 자식 작업을 가질 수 있습니다.
작업과 작업 그룹 간의 명시적 관계 때문에
이 접근법을 *구조화된 동시성 (structured concurrency)* 이라고 합니다.
작업 간의 명시적 부모-자식 관계에는 다음과 같은 여러 이점이 있습니다.

- 부모 작업에서는
  자식 작업들이 완료되기를 기다리는 것을 잊을 수 없습니다.

- 자식 작업에 더 높은 우선순위를 설정하면
  부모 작업의 우선순위가 자동으로 승격됩니다.

- 부모 작업이 취소되면
  각 자식 작업도 자동으로 취소됩니다.

- 한 작업에 국한된 값들이 자식 작업들로 효율적이고 자동적이게 전파됩니다.

다음은 사진을 다운로드하는 코드의 다른 버전으로, 임의의 수의 사진을 처리합니다.

```swift
await withTaskGroup(of: Data.self) { group in
    let photoNames = await listPhotos(inGallery: "Summer Vacation")
    for name in photoNames {
        group.addTask {
            return await downloadPhoto(named: name)
        }
    }

    for await photo in group {
        show(photo)
    }
}
```

위 코드는 새로운 작업 그룹을 생성한 다음
갤러리의 각 사진을 다운로드하기 위한 자식 작업들을 생성합니다.
Swift는 조건이 허용하는 한 이러한 작업들을 동시에 실행합니다.
자식 작업이 사진 다운로드를 완료하는 즉시
해당 사진이 표시됩니다.
자식 작업들이 완료되는 순서에 대한 보장은 없으므로
이 갤러리의 사진들은 임의의 순서로 표시될 수 있습니다.

> 참고:
> 사진을 다운로드하는 코드가 에러를 던질 수 있다면
> 대신 `withThrowingTaskGroup(of:returning:body:)`를 호출합니다.

위의 코드는 각 사진을 다운로드한 후 표시까지 하므로,
작업 그룹이 결과를 반환할 필요가 없습니다.
결과를 반환하는 작업 그룹의 경우
`withTaskGroup(of:returning:body:)`에 전달하는 클로저 내부에
결과를 누적하는 코드를 추가합니다.

```swift
let photos = await withTaskGroup(of: Data.self) { group in
    let photoNames = await listPhotos(inGallery: "Summer Vacation")
    for name in photoNames {
        group.addTask {
            return await downloadPhoto(named: name)
        }
    }

    var results: [Data] = []
    for await photo in group {
        results.append(photo)
    }

    return results
}
```

이전 예시와 마찬가지로
이 예시는 각 사진을 다운로드하기 위한 자식 작업을 생성합니다.
이전 예시와 달리
`for`-`await`-`in` 반복문은 다음 자식 작업이 완료되기를 기다리고,
해당 작업의 결과를 결과 배열에 추가한 다음,
모든 자식 작업이 완료될 때까지 계속 기다립니다.
마지막으로
작업 그룹은 다운로드된 사진들의 배열을
최종 결과로 반환합니다.

<!--
TODO:
In the future,
we could extend the example above
to show how you can limit the number of concurrent tasks
that get spun up by a task group.
There isn't a specific guideline we can give
in terms of how many concurrent tasks to run --
it's more "profile your code, and then adjust".

See also:
https://developer.apple.com/videos/play/wwdc2023/10170?time=688

We could also show withDiscardingTaskGroup(...)
since that's optimized for child tasks
whose values aren't collected.
-->

### 작업 취소 (Task Cancellation)

Swift 동시성은 협력적 취소 모델을 채택합니다.
각 작업은 실행 중 적절한 지점에서 자신이 취소되었는지 확인하고,
취소에 적절히 대응합니다.
취소에 대응하는 방식은 작업마다 다르지만 보통 다음 중 하나입니다.

- `CancellationError`와 같은 에러 던지기
- `nil`이나 빈 컬렉션 반환하기
- 부분적으로 완료된 작업 반환하기

사진 다운로드는 사진이 크거나 네트워크가 느린 경우 오래 걸릴 수 있습니다.
사용자가 모든 작업이 완료되기를 기다리지 않고
이 작업을 중단할 수 있게 하려면,
작업들이 취소를 확인하고 취소된 경우 실행을 중단해야 합니다.
작업이 이를 수행하는 방법은 두 가지입니다.
[`Task.checkCancellation()`][] 타입 메서드를 호출하거나
[`Task.isCancelled`][`Task.isCancelled` type] 타입 프로퍼티를 읽는 것입니다.
`checkCancellation()`을 호출하면 작업이 취소된 경우 에러를 던집니다.
에러를 던지는 작업은 에러를 작업 밖으로 전파하여
작업의 모든 일을 중단할 수 있습니다.
이는 구현하고 이해하기 쉽다는 장점이 있습니다.
더 많은 유연성이 필요한 경우 `isCancelled` 프로퍼티를 사용하면
작업을 중단하는 과정에서 정리 작업을 수행할 수 있습니다.
예컨대 네트워크 연결을 닫고 임시 파일을 삭제하는 등의 일을 할 수 있습니다.

[`Task.checkCancellation()`]: https://developer.apple.com/documentation/swift/task/3814826-checkcancellation
[`Task.isCancelled` type]: https://developer.apple.com/documentation/swift/task/iscancelled-swift.type.property

```swift
let photos = await withTaskGroup { group in
    let photoNames = await listPhotos(inGallery: "Summer Vacation")
    for name in photoNames {
        let added = group.addTaskUnlessCancelled {
            Task.isCancelled ? nil : await downloadPhoto(named: name)
        }
        guard added else { break }
    }

    var results: [Data] = []
    for await photo in group {
        if let photo { results.append(photo) }
    }
    return results
}
```

위 코드에는 이전 버전과 비교해 몇 가지 변경 사항이 있습니다.

- 각 작업은
  [`TaskGroup.addTaskUnlessCancelled(priority:operation:)`][] 메서드를 사용하여 추가되어
  취소 후에 새로운 작업이 시작되지 않도록 합니다.

- `addTaskUnlessCancelled(priority:operation:)` 호출 후마다
  코드는 새로운 자식 작업이 추가되었는지 확인합니다.
  그룹이 취소된 경우 `added`의 값은 `false`이고,
  이 경우 코드는 더 이상 사진 다운로드 시도를 시작하지 않습니다.

- 각 작업은 사진을 다운로드하기 시작하기 전에 취소를 확인합니다.
  취소된 경우 작업은 `nil`을 반환합니다.

- 마지막에 작업 그룹은 결과를 수집할 때 `nil` 값을 건너뜁니다.
  이렇게 `nil`을 반환하여 취소를 처리하는 경우 작업 그룹은 부분적 결과를 반환할 수 있습니다.
  취소 시점에서 이미 다운로드된 사진들은 반환되기 때문에 완료된 작업을 버리지 않아도 됩니다.

[`TaskGroup.addTaskUnlessCancelled(priority:operation:)`]: https://developer.apple.com/documentation/swift/taskgroup/addtaskunlesscancelled(priority:operation:)

> 참고:
> 해당 작업 외부에서 작업이 취소되었는지 확인하려면
> 타입 프로퍼티 대신 [`Task.isCancelled`][`Task.isCancelled` instance] 인스턴스 프로퍼티를
> 사용합니다.

[`Task.isCancelled` instance]: https://developer.apple.com/documentation/swift/task/iscancelled-swift.property

취소를 즉시 알림받아야 하는 작업의 경우
[`Task.withTaskCancellationHandler(operation:onCancel:isolation:)`][] 메서드를 사용합니다.
예를 들어:

[`Task.withTaskCancellationHandler(operation:onCancel:isolation:)`]: https://developer.apple.com/documentation/swift/withtaskcancellationhandler(operation:oncancel:isolation:)

```swift
let task = await Task.withTaskCancellationHandler {
    // ...
} onCancel: {
    print("Canceled!")
}

// ... some time later...
task.cancel()  // Prints "Canceled!"
```

취소 핸들러를 사용할 때도
작업 취소는 여전히 협력적입니다.
작업은 완료까지 실행되거나
취소를 확인하고 일찍 중단됩니다.
취소 핸들러가 시작되는 시점에서 작업은 여전히 실행 중이기 때문에,
작업과 취소 핸들러 간의 상태 공유는 경합을 일으킬 수 있고, 따라서 피해야 합니다.

<!--
  OUTLINE

  - cancellation propagates (Konrad's example below)

  ::

      let handle = Task.detached {
      await withTaskGroup(of: Bool.self) { group in
          var done = false
          while done {
          await group.addTask { Task.isCancelled } // is this child task canceled?
          done = try await group.next() ?? false
          }
      print("done!") // <1>
      }

      handle.cancel()
      // done!           <1>
-->

<!--
  Not for WWDC, but keep for future:

  task have deadlines, not timeouts --- like "now + 20 ms" ---
  a deadline is usually what you want anyhow when you think of a timeout

  - this chapter introduces the core ways you use tasks;
  for the full list what you can do,
  including the unsafe escape hatches
  and ``Task.current()`` for advanced use cases,
  see the Task API reference [link to stdlib]

  - task cancellation isn't part of the state diagram below;
  it's an independent property that can happen in any state

  [PLACEHOLDER ART]

  Task state diagram

     |
     v
  Suspended <-+
     |        |
     v        |
  Running ----+
     |
     v
  Completed

  [PLACEHOLDER ART]

  Task state diagram, including "substates"

     |
     v
  Suspended <-----+
  (Waiting) <---+ |
     |          | |
     v          | |
  Suspended     | |
  (Schedulable) / |
     |            |
     v            |
  Running --------+
     |
     v
  Completed

  .. _Concurrency_ChildTasks:

  Adding Child Tasks to a Task Group

  - awaiting ``withGroup`` means waiting for all child tasks to complete

  - a child task can't outlive its parent,
  like how ``async``-``let`` can't outlive the (implicit) parent
  which is the function scope

  - awaiting ``addTask(priority:operation:)``
  means waiting for that child task to be added,
  not waiting for that child task to finish

  - ?? maybe cover ``TaskGroup.next``
  probably nicer to use the ``for await result in someGroup`` syntax

  quote from the SE proposal --- I want to include this fact here too

  > There's no way for reference to the child task to
  > escape the scope in which the child task is created.
  > This ensures that the structure of structured concurrency is maintained.
  > It makes it easier to reason about
  > the concurrent tasks that are executing within a given scope,
  > and also enables various optimizations.
-->

<!--
  OUTLINE

  .. _Concurrency_TaskPriority:

  Setting Task Priority

  - priority values defined by ``Task.Priority`` enum

  - type property ``Task.currentPriority``

  - The exact result of setting a task's priority depends on the executor

  - TR: What's the built-in stdlib executor do?

  - Child tasks inherit the priority of their parents

  - If a high-priority task is waiting for a low-priority one,
  the low-priority one gets scheduled at high priority
  (this is known as :newTerm:`priority escalation`)

  - In addition, or instead of, setting a low priority,
  you can use ``Task.yield()`` to explicitly pass execution to the next scheduled task.
  This is a sort of cooperative multitasking for long-running work.

You can explicitly insert a suspension point
by calling the [`Task.yield()`][] method.

[`Task.yield()`]: https://developer.apple.com/documentation/swift/task/3814840-yield

```swift
func generateSlideshow(forGallery gallery: String) async {
    let photos = await listPhotos(inGallery: gallery)
    for photo in photos {
        // ... render a few seconds of video for this photo ...
        await Task.yield()
    }
}
```

Assuming the code that renders video is synchronous,
it doesn't contain any suspension points.
The work to render video could also take a long time.
However,
you can periodically call `Task.yield()`
to explicitly add suspension points.
Structuring long-running code this way
lets Swift balance between making progress on this task,
and letting other tasks in your program make progress on their work.
-->

### 비구조화된 동시성 (Unstructured Concurrency)

앞 절에서 설명한 구조화된 동시성 접근법 외에도
Swift는 비구조화된 동시성을 지원합니다.
작업 그룹의 일부인 작업과 달리
*비구조화된 작업* 은 부모 작업이 없습니다.
프로그램이 필요로 하는 방식으로 비구조화된 작업을 관리하는
완전한 유연성을 얻는 대신, 코드의 정확성에 대한 책임도 지게 됩니다.

주변 코드와 유사하게 실행되는 비구조화된 작업을 생성하려면
[`Task.init(priority:operation:)`][] 초기화자를 호출합니다.
이 작업은 기본적으로 현재 작업과 동일한
액터 격리, 우선 순위, 작업 로컬 상태로 실행됩니다.
주변 코드로부터 더 독립적인 비구조화된 작업을 생성하려면,
더 구체적으로는 *분리된 작업* 이라고 알려진 작업을 생성하려면,
[`Task.detached(priority:operation:)`][] 정적 메서드를 호출합니다.
이 작업은 기본적으로 액터 격리 없이 실행되며
현재 작업의 우선순위나 작업 로컬 상태를 상속받지 않습니다.
여기서 언급한 두 연산 모두 상호작용할 수 있는 작업을 반환하고, 따라서 결과를 기다리거나 취소할 수 있습니다.
<!-- TODO: In SE-0461 terms, Task.detached runs as an @concurrent function. -->

```swift
let newPhoto = // ... some photo data ...
let handle = Task {
    return await add(newPhoto, toGalleryNamed: "Spring Adventures")
}
let result = await handle.value
```

분리된 작업 관리에 대한 더 자세한 정보는
[`Task`](https://developer.apple.com/documentation/swift/task)를 참고하십시오.

[`Task.init(priority:operation:)`]: https://developer.apple.com/documentation/swift/task/init(priority:operation:)-7f0zv
[`Task.detached(priority:operation:)`]: https://developer.apple.com/documentation/swift/task/detached(priority:operation:)-d24l

<!--
  TODO Add some conceptual guidance about
  when to make a method do its work in a detached task
  versus making the method itself async?
  (Pull from my 2021-04-21 notes from Ben's talk rehearsal.)
-->

## 격리 (Isolation)

이전 절들에서는 동시성 작업을 분할하는 접근법을 다뤘는데,
이 과정에서 앱의 UI와 같은 공유 데이터를 변경할 필요가 있을 수 있습니다.
코드의 서로 다른 부분이 동시에 같은 데이터를 수정할 수 있다면
데이터 경합이 발생할 위험이 있습니다.
Swift는 데이터를 읽거나 수정할 때마다 다른 코드가 동시에 그것을 수정하지 않도록 보장함으로써 데이터 경합을 차단할 수 있습니다.
이러한 보장을 *데이터 격리 (data isolation)* 라고 합니다.
데이터를 격리하는 주요 방법은 세 가지입니다.

1. 불변 데이터는 항상 격리됩니다.
   상수는 수정할 수 없으므로
   상수를 읽는 것과 동시에 다른 코드가 상수를 수정할 위험이 없습니다.

2. 현재 작업에서만 참조되는 데이터는 항상 격리됩니다.
   로컬 변수는 작업 외부의 코드가 해당 메모리에 대한 참조를 갖지 않으므로
   안전하게 읽고 쓸 수 있어서, 다른 코드가 해당 데이터를 수정할 수 없습니다.
   또한 그 변수를 클로저에서 캡처하는 경우,
   Swift는 클로저가 동시에 사용되지 않도록 보장합니다.

3. 액터에 의해 보호되는 데이터는 동일한 액터에 격리된 코드가 접근하는 경우 격리 상태입니다.
   현재 함수가 액터에 격리되어 있다면,
   해당 액터에 의해 보호되는 데이터를 안전하게 읽고 쓸 수 있습니다.
   동일한 액터에 격리된 다른 코드는
   실행되기 전에 순서를 기다려야 하기 때문입니다.

## 메인 액터 (The Main Actor)

액터는 가변 데이터가 순서를 돌아가며 접근되도록 강제함으로써
가변 데이터에 대한 접근을 보호하는 객체입니다.
많은 프로그램에서 가장 중요한 액터는 *메인 액터* 입니다.
앱에서 메인 액터는 UI를 표시하는 데 사용되는 모든 데이터를 보호합니다.
메인 액터는 UI 렌더링이나 UI 이벤트 처리, UI에 대한 질의 혹은 업데이트를 행하는 코드를 순차적으로 실행합니다.

코드에서 동시성을 사용하기 시작하기 전에는
모든 것이 메인 액터에서 실행됩니다.
오래 실행되거나 리소스를 많이 사용하는 코드를 발견했다면,
안전성과 정확성을 유지하면서 이 작업을 메인 액터 밖으로 옮길 수 있습니다.

> 참고:
> 메인 액터는 메인 스레드와 밀접하게 관련되어 있지만,
> 둘은 엄밀히는 같은 것이 아닙니다.
> 메인 스레드는 메인 액터의 비공개 가변 상태에 대한 접근을 직렬화하고,
> 메인 액터에서 코드를 실행할 때
> Swift는 해당 코드를 메인 스레드에서 실행합니다.
> 이러한 연관성 때문에
> 두 용어가 서로 혼동되어 사용되는 것을 볼 수 있습니다.
> 코드는 메인 액터와 상호작용하고,
> 메인 스레드는 더 낮은 수준의 구현 디테일입니다.

<!--
TODO: Discuss the SE-0478 syntax for 'using @MainActor'

When you're writing UI code,
you often want all of it to be isolated to the main actor.
To do this, you can write `using @MainActor`
at the top of a Swift file to apply that attribute by default
to all the code in the file.
If there's a specific function or property
that you want to exclude from `using @MainActor`,
you can use the `nonisolated` modifier on that declaration
to override the default.
Modules can be configured to be built using `using @MainActor` by default.
This can be overridden on a per-file basis
by writing `using nonisolated` at the top of a file.
-->

메인 액터에서 작업을 실행하는 방법은 여러 가지가 있습니다.
함수가 항상 메인 액터에서 실행되도록 하려면
`@MainActor` 속성으로 표시합니다.

```swift
@MainActor
func show(_: Data) {
    // ... UI code to display the photo ...
}
```

위 코드에서 `show(_:)` 함수의 `@MainActor` 속성은
이 함수가 메인 액터에서만 실행되도록 요구합니다.
메인 액터에서 실행되는 다른 코드 내에서는
`show(_:)`를 동기 함수로 호출할 수 있습니다.
다만 메인 액터에서 실행되지 않는 코드에서 `show(_:)`를 호출하려면
`await`를 붙여서 비동기 함수로 호출해야 합니다.
메인 액터로 전환하는 것이 잠재적으로 일시 정지 지점을 도입할 수 있기 때문입니다.

```swift
func downloadAndShowPhoto(named name: String) async {
    let photo = await downloadPhoto(named: name)
    await show(photo)
}
```

예컨대 위 코드에서 `downloadPhoto(named:)`와 `show(_:)` 함수
모두 호출할 때 일시 정지될 수 있습니다.
이 코드에서처럼, 오래 실행되고 CPU 집약적인 작업은 백그라운드에서 수행하고
UI를 업데이트하기 위해 메인 액터로 전환하는 것이 일반적인 패턴입니다.
`downloadPhoto(named:)`는 메인 액터에서 실행되지 않는데,
이는 `downloadAndShowPhoto(named:)` 함수가 메인 액터에 있지 않기 때문입니다.
UI를 업데이트하는 `show(_:)`의 일만이 메인 액터에서 실행되고,
이는 `show(_:)`가 `@MainActor` 속성으로 표시되었기 때문입니다.
<!-- TODO
When updating for SE-0461,
this is a good place to note
that downloadPhoto(named:) runs
on whatever actor you were on when you called it.
-->

클로저가 메인 액터에서 실행되도록 하려면
클로저 시작 부분의 캡처 목록과 `in` 앞에 `@MainActor`를 적습니다.

```swift
let photo = await downloadPhoto(named: "Trees at Sunrise")
Task { @MainActor in
    show(photo)
}
```

위 코드는 이전에 코드의 `downloadAndShowPhoto(named:)`와 유사하지만,
이 예시의 경우 UI 업데이트가 끝날 때까지 기다리지 않습니다.
구조체, 클래스 또는 열거형에 `@MainActor`를 적어
모든 메서드와 모든 프로퍼티 접근이
메인 액터에서 실행되도록 할 수도 있습니다.

```swift
@MainActor
struct PhotoGallery {
    var photoNames: [String]
    func drawUI() { /* ... other UI code ... */ }
}
```

위 코드의 `PhotoGallery` 구조체는
화면에 사진을 표시하는데,
`photoNames` 프로퍼티의 이름을 사용하여
표시할 사진을 결정합니다.
`photoNames`는 UI에 영향을 주므로
이를 변경하는 코드는 메인 액터에서 실행되어
해당 접근을 직렬화해야 합니다.

프레임워크를 기반으로 구축할 때는
해당 프레임워크의 프로토콜과 기본 클래스가
일반적으로 이미 `@MainActor`로 표시되어 있으므로
이 경우 자신의 타입에 `@MainActor`를 적을 필요가 없습니다.
다음은 단순화된 예시입니다.

```swift
@MainActor
protocol View { /* ... */ }

// Implicitly @MainActor
struct PhotoGalleryView: View { /* ... */ }
```

위 코드에서 SwiftUI와 같은 프레임워크는 `View` 프로토콜을 정의합니다.
프로토콜 선언에 `@MainActor`를 적으면
프로토콜을 준수하는 `PhotoGalleryView`와 같은 타입도
암묵적으로 `@MainActor`로 표시됩니다.
`View`가 기본 클래스이고 `PhotoGalleryView`가 서브클래스인 경우에도 동일하게
`PhotoGalleryView`가 `@MainActor`로 표시됩니다.

위 예시에서 `PhotoGallery`는 메인 액터에서 전체 구조체를 보호합니다.
더 세밀한 제어를 위해서는
메인 스레드에서 접근되거나 실행되어야 하는 프로퍼티나 메서드에만
`@MainActor`를 적을 수 있습니다.

```swift
struct PhotoGallery {
    @MainActor var photoNames: [String]
    var hasCachedPhotos = false

    @MainActor func drawUI() { /* ... UI code ... */ }
    func cachePhotos() { /* ... networking code ... */ }
}
```

위 버전의 `PhotoGallery`에서
`drawUI()` 메서드는 갤러리의 사진을 화면에 표시하므로
메인 액터에 격리되어야 합니다.
`photoNames` 프로퍼티는 UI를 직접 생성하지는 않지만,
`drawUI()` 함수가 UI를 그리는 데 사용하는 상태를 저장하므로
이 프로퍼티도 메인 액터에서만 접근되어야 합니다.
반면 `hasCachedPhotos` 프로퍼티의 변경은
UI와 상호작용하지 않고,
`cachePhotos()` 메서드는 메인 액터에서 실행되어야 하는
상태에 접근하지 않습니다.
따라서 이들은 `@MainActor`로 표시되지 않습니다.

앞의 예시들과 마찬가지로
UI를 구축하기 위해 프레임워크를 사용하는 경우,
해당 프레임워크의 프로퍼티 래퍼가
이미 UI 상태 프로퍼티를 `@MainActor`로 표시할 것입니다.
프로퍼티 래퍼를 정의할 때
`wrappedValue` 프로퍼티가 `@MainActor`로 표시되면,
해당 프로퍼티 래퍼를 적용하는 모든 프로퍼티도
암묵적으로 `@MainActor`로 표시됩니다.

## 액터 (Actors)

Swift가 제공하는 메인 액터 외에도 개발자가 직접 액터를 정의할 수 있습니다.
액터를 사용하면 동시성 코드 간에 정보를 안전하게 공유할 수 있습니다.

클래스와 마찬가지로 액터는 참조 타입이므로
<doc:ClassesAndStructures#Classes-Are-Reference-Types>에서
값 타입과 참조 타입을 비교한 내용이
클래스뿐만 아니라 액터에도 적용됩니다.
클래스와 달리
액터는 한 번에 하나의 작업만 가변 상태에 접근하도록 허용하므로
여러 작업의 코드가 동일한 액터 인스턴스와
상호작용하는 것이 안전합니다.
예를 들어, 다음은 온도를 기록하는 액터입니다.

```swift
actor TemperatureLogger {
    let label: String
    var measurements: [Int]
    private(set) var max: Int

    init(label: String, measurement: Int) {
        self.label = label
        self.measurements = [measurement]
        self.max = measurement
    }
}
```

<!--
  - test: `actors, actors-implicitly-sendable`

  ```swifttest
  -> actor TemperatureLogger {
         let label: String
         var measurements: [Int]
         private(set) var max: Int

         init(label: String, measurement: Int) {
             self.label = label
             self.measurements = [measurement]
             self.max = measurement
         }
     }
  ```
-->

`actor` 키워드와 그 뒤에 오는 중괄호 안의 정의로 액터를 도입합니다.
`TemperatureLogger` 액터는 액터 외부의 다른 코드가 접근할 수 있는 프로퍼티를 가지며,
`max` 프로퍼티는 액터 내부의 코드만
최댓값을 업데이트할 수 있도록 제한합니다.

구조체와 클래스와 동일한 초기화자 문법을 사용하여
액터의 인스턴스를 생성합니다.
액터의 프로퍼티나 메서드에 접근할 때는
`await`를 사용하여 일시 정지 가능 지점을 표시합니다.
예를 들어:

```swift
let logger = TemperatureLogger(label: "Outdoors", measurement: 25)
print(await logger.max)
// Prints "25"
```

이 예시에서 `logger.max`에 접근하는 것은 가능한 일시 정지 지점입니다.
액터는 한 번에 하나의 작업만 가변 상태에 접근하도록 허용하므로,
다른 작업의 코드가 이미 로거와 상호작용하고 있다면
이 코드는 프로퍼티에 접근하기를 기다리는 동안 일시 정지됩니다.

반면 액터의 일부인 코드는
액터의 프로퍼티에 접근할 때 `await`를 적지 않습니다.
예를 들어, 다음은 `TemperatureLogger`를 새로운 온도로 업데이트하는 메서드입니다.

```swift
extension TemperatureLogger {
    func update(with measurement: Int) {
        measurements.append(measurement)
        if measurement > max {
            max = measurement
        }
    }
}
```

`update(with:)` 메서드는 이미 액터에서 실행되고 있으므로
`max`와 같은 프로퍼티에 대한 접근을 `await`로 표시하지 않습니다.
또한 이 메서드는 액터가 한 번에 하나의 작업만
가변 상태와 상호작용하도록 허용하는 한 가지 이유를 보여주는데, 이는
액터 상태를 업데이트할 때 일시적으로 불변량을 변경할 수 있기 때문입니다.
`TemperatureLogger` 액터는
온도 목록과 최고 온도를 추적하고,
새로운 측정값을 기록할 때 최고 온도를 업데이트합니다.
업데이트 중간에는
새로운 측정값을 추가한 후 `max`를 업데이트하기 전에
온도 로거가 일시적으로 불일치 상태에 있습니다.
여러 작업이 동시에 동일한 인스턴스와 상호작용하는 것을 방지하면
다음과 같은 이벤트 순서로 인한 문제를 예방할 수 있습니다.

1. 코드가 `update(with:)` 메서드를 호출합니다.
   먼저 `measurements` 배열을 업데이트합니다.
2. 코드가 `max`를 업데이트하기 전에
   다른 곳의 코드가 최댓값과 온도 배열을 읽습니다.
3. 코드가 `max`를 변경하여 업데이트를 완료합니다.

이 경우 다른 곳에서 실행되는 코드는
`update(with:)` 호출 중간에 액터에 대한 접근이 끼어들어
데이터가 일시적으로 유효하지 않은 동안
잘못된 정보를 읽게 됩니다.
Swift 액터를 사용하면 이러한 문제를 예방할 수 있습니다.
액터는 자신의 상태에 한 번에 하나의 연산만 접근할 수 있게 하고,
`await`로 표시된 일시 정지 지점에서만 연산을 멈추기 떄문입니다.
`update(with:)`에는 일시 정지 지점이 없으므로
다른 코드가 업데이트 중간에 데이터에 접근할 수 없습니다.

액터 외부의 코드가 구조체나 클래스의 프로퍼티에 접근하듯 액터의 프로퍼티에 직접 접근하려고 시도하면
컴파일 시점에서 에러가 발생합니다.

```swift
print(logger.max)  // Error
```

이 예시에서 `await`를 적지 않고 `logger.max`에 접근하는 것은 실패합니다.
액터의 프로퍼티는 해당 액터의 격리된 로컬 상태의 일부이기 때문입니다.
이 프로퍼티에 접근하는 코드는 해당 액터의 일부로 실행되어야 하는데,
이는 비동기 연산이며 `await` 표시가 필요합니다.
Swift는 같은 액터에서 실행되는 코드만
해당 액터의 로컬 상태에 접근할 수 있음을 보장합니다.
이러한 보장을 *액터 격리 (actor isolation)* 라고 합니다.

Swift 동시성 모델의 다음 측면들이 함께 작동하여
공유 가변 상태에 대해 추론하기 쉽게 만듭니다.

- 일시 정지 가능 지점 사이의 코드는 순차적으로 실행되어
  다른 동시성 코드에 의해 중단될 가능성이 없습니다.
  다만 여러 동시성 코드가 동시에 실행되는 것은 가능하므로,
  다른 코드가 동시에 실행될 수는 있습니다.

- 액터의 로컬 상태와 상호작용하는 코드는
  해당 액터에서만 실행됩니다.

- 액터는 한 번에 하나의 코드만 실행합니다.

이러한 보장 덕분에,
`await`가 없고 액터 내부에 있는 코드는
프로그램의 다른 곳에 유효하지 않은 상태를 노출할 위험 없이 업데이트를 수행할 수 있습니다.
예를 들어, 다음 코드는 측정된 온도를 화씨에서 섭씨로 변환합니다.

```swift
extension TemperatureLogger {
    func convertFahrenheitToCelsius() {
        for i in measurements.indices {
            measurements[i] = (measurements[i] - 32) * 5 / 9
        }
    }
}
```

위 코드는 측정값 배열을 한 번에 하나씩 변환합니다.
맵 연산이 진행되는 동안
일부 온도는 화씨이고 다른 온도는 섭씨입니다.
다만 코드에 `await`가 포함되지 않으므로
이 메서드에는 일시 정지 가능 지점이 없습니다.
이 메서드가 수정하는 상태는 액터에 속하므로,
해당 코드가 액터에서 실행될 때를 제외하고는
다른 코드가 읽거나 수정하지 못하도록 보호됩니다.
즉, 단위 변환이 진행되는 동안
다른 코드가 부분적으로 변환된 온도 목록을 읽을 방법이 없습니다.

액터 안에 일시 정지 가능 지점 없이 코드를 적는 것과 더불어,
코드를 동기 메서드 안으로 옮김으로써도 유효하지 않은 상태에의 접근을 막을 수 있습니다.
위의 `convertFahrenheitToCelsius()` 메서드는 동기 메서드이므로
일시 정지 가능 지점을 *절대* 포함하지 않는다고 보장됩니다.
이 함수는 데이터 모델을 일시적으로 불일치하게 만드는 코드를 캡슐화하고,
코드를 읽는 사람으로 하여금 다른 코드가 실행되기 전에
데이터 일관성이 복원된다는 사실을 인식하기 쉽게 만듭니다.
여기서 중요한 것은 Swift가 이 구간을 실행하는 도중에 프로그램의 다른 부분으로 전환하지 않는다는 것입니다.
만약 미래에 이 함수에 동시성 코드를 추가하여 일시 정지 가능 시점을 도입하려 시도한다면,
버그를 만드는 대신 컴파일 시점 에러를 일으킬 것입니다.


## 글로벌 액터 (Global Actors)

메인 액터는 [`MainActor`][] 타입의 글로벌 싱글톤 인스턴스입니다.
액터는 일반적으로 여러 인스턴스를 가질 수 있으며,
각각 독립적인 격리를 제공합니다.
이것이 액터의 모든 격리된 데이터를
해당 액터의 인스턴스 프로퍼티로 선언하는 이유입니다.
다만 `MainActor`는 싱글톤이므로
이 타입의 인스턴스는 단 하나만 존재합니다.
따라서 타입만으로 액터를 식별하기에 충분하여
속성만으로 메인 액터 격리를 표시할 수 있습니다.
이러한 접근법은 여러분에게 가장 적합한 방식으로
코드를 구성할 수 있게끔 유연성을 제공합니다.

[`MainActor`]: https://developer.apple.com/documentation/swift/mainactor

<doc:Attributes#globalActor>에서 설명하는 것처럼
`@globalActor` 속성을 사용하여
자신만의 싱글톤 글로벌 액터를 정의할 수 있습니다.


<!--
  OUTLINE

  Add this post-WWDC when we have a more solid story to tell around Sendable

   .. _Concurrency_ActorIsolation:

   Actor Isolation

   TODO outline impact from SE-0313 Control Over Actor Isolation
   about the 'isolated' and 'nonisolated' keywords

   - actors protect their mutable state using :newTerm:`actor isolation`
   to prevent data races
   (one actor reading data that's in an inconsistent state
   while another actor is updating/writing to that data)

   - within an actor's implementation,
   you can read and write to properties of ``self`` synchronously,
   likewise for calling methods of ``self`` or ``super``

   - method calls from outside the actor are always async,
   as is reading the value of an actor's property

   - you can't write to a property directly from outside the actor

   - The same actor method can be called multiple times, overlapping itself.
   This is sometimes referred to as *reentrant code*.
   The behavior is defined and safe... but might have unexpected results.
   However, the actor model doesn't require or guarantee
   that these overlapping calls behave correctly (that they're *idempotent*).
   Encapsulate state changes in a synchronous function
   or write them so they don't contain an ``await`` in the middle.

   - If a closure is ``@Sendable`` or ``@escaping``
   then it behaves like code outside of the actor
   because it could execute concurrently with other code that's part of the actor

   exercise the log actor, using its client API to mutate state

   ::

       let logger = TemperatureSensor(lines: [
           "Outdoor air temperature",
           "25 C",
           "24 C",
       ])
       print(await logger.getMax())

       await logger.update(with: "27 C")
       print(await logger.getMax())
-->

## Sendable 타입 (Sendable Types)

작업과 액터를 사용하면 프로그램을
안전하게 동시에 실행될 수 있는 조각들로 나눌 수 있습니다.
작업이나 액터 인스턴스 내에서,
변수와 프로퍼티와 같은 가변 상태를 다루는 프로그램의 조각을
*동시성 도메인 (concurrency domain)* 이라고 합니다.
일부 종류의 데이터는 동시성 도메인 간에 공유될 수 없는데,
그 데이터가 가변 상태를 갖지만 동시에 여러 접근이 이뤄지는 경우에 대한 보호를 제공하지 않기 때문입니다.

한 동시성 도메인에서 다른 도메인으로 공유될 수 있는 타입을
*sendable* 타입이라고 합니다.
예를 들어, 액터 메서드를 호출할 때 인자로 전달되거나
작업의 결과로 반환될 수 있습니다.
이 장의 앞부분 예시들은 sendability에 대해 논의하지 않았는데,
해당 예시들이 동시성 도메인 간에 전달되는 데이터에 대해
항상 공유하기 안전한 간단한 값 타입을 사용했기 때문입니다.
반면 일부 타입은 동시성 도메인을 넘나들며 전달하기에 안전하지 않습니다.
예를 들어, 가변 프로퍼티를 가지며
해당 프로퍼티에 대한 접근을 직렬화하지 않는 클래스는
서로 다른 작업 간에 해당 클래스의 인스턴스를 전달할 때
예측할 수 없고 잘못된 결과를 일으킬 수 있습니다.

타입이 sendable임을 표시하려면
`Sendable` 프로토콜 준수를 선언합니다.
해당 프로토콜에는 코드 요구사항이 없지만,
Swift가 강제하는 의미적 요구사항이 있습니다.
일반적으로 타입이 sendable이 되는 방법은 세 가지입니다.

- 타입이 값 타입이고 가변 상태가 다른 sendable 데이터로 구성되는 경우.
  예를 들어, sendable인 저장 프로퍼티를 가진 구조체나
  sendable인 연관 값을 가진 열거형입니다.
- 타입이 가변 상태를 갖지 않고 불변 상태가 다른 sendable 데이터로 구성되는 경우.
  예를 들어, 읽기 전용 프로퍼티만 가진 구조체나 클래스입니다.
- 타입에 가변 상태의 안전성을 보장하는 코드가 있는 경우.
  예를 들어, `@MainActor`로 표시된 클래스나
  특정 스레드나 큐에서 프로퍼티에 대한 접근을 직렬화하는 클래스입니다.

<!--
  There's no example of the third case,
  where you serialize access to the class's members,
  because the stdlib doesn't include the locking primitives you'd need.
  Implementing it in terms of NSLock or some Darwin API
  isn't a good fit for TSPL.
  Implementing it in terms of isKnownUniquelyReferenced(_:)
  and copy-on-write is also probably too involved for TSPL.
-->

의미적 요구사항의 자세한 목록은
[`Sendable`](https://developer.apple.com/documentation/swift/sendable) 프로토콜 레퍼런스를 참조하십시오.

일부 타입은 항상 sendable입니다.
예를 들어, sendable 프로퍼티만 가진 구조체와
sendable 연관 값만 가진 열거형입니다.

```swift
struct TemperatureReading: Sendable {
    var measurement: Int
}

extension TemperatureLogger {
    func addReading(from reading: TemperatureReading) {
        measurements.append(reading.measurement)
    }
}

let logger = TemperatureLogger(label: "Tea kettle", measurement: 85)
let reading = TemperatureReading(measurement: 45)
await logger.addReading(from: reading)
```

<!--
  - test: `actors`

  ```swifttest
  -> struct TemperatureReading: Sendable {
         var measurement: Int
     }

  -> extension TemperatureLogger {
         func addReading(from reading: TemperatureReading) {
             measurements.append(reading.measurement)
         }
     }

  -> let logger = TemperatureLogger(label: "Tea kettle", measurement: 85)
  -> let reading = TemperatureReading(measurement: 45)
  -> await logger.addReading(from: reading)
  ```
-->

위 예시에서 `TemperatureReading`은 sendable 프로퍼티만 가진 구조체이고,
구조체가 `public`이나 `@usableFromInline`으로 표시되지 않았으므로
암묵적으로 sendable입니다.
다음은 `Sendable` 프로토콜 준수가 암시된 구조체 버전입니다.

```swift
struct TemperatureReading {
    var measurement: Int
}
```

<!--
  - test: `actors-implicitly-sendable`

  ```swifttest
  -> struct TemperatureReading {
         var measurement: Int
     }
  ```
-->

타입이 sendable하지 않음을 명시적으로 표시하려면
`Sendable` 준수를 사용할 수 없음으로 표시합니다.

```swift
struct FileDescriptor {
    let rawValue: Int
}

@available(*, unavailable)
extension FileDescriptor: Sendable {}
```

<!--
The example above is based on a Swift System API.
https://github.com/apple/swift-system/blob/main/Sources/System/FileDescriptor.swift

See also this PR that adds Sendable conformance to FileDescriptor:
https://github.com/apple/swift-system/pull/112
-->

사용할 수 없음 표시를 사용하여
<doc:Protocols#Implicit-Conformance-to-a-Protocol>에서 논의된 대로
프로토콜에 대한 암시적 준수를 억제할 수도 있습니다.

<!--
  LEFTOVER OUTLINE BITS

  - like classes, actors can inherit from other actors

  - actors can also inherit from ``NSObject``,
  which lets you mark them ``@objc`` and do interop stuff with them

  - every actor implicitly conforms to the ``Actor`` protocol,
  which has no requirements

  - you can use the ``Actor`` protocol to write code that's generic across actors

  - In the future, when we get distributed actors,
    the TemperatureSensor example
    might be a good example to expand when explaining them.

  ::

      while let result = try await group.next() { }
      for try await result in group { }

  how much should you have to understand threads to understand this?
  Ideally you don't have to know anything about them.

  How do you meld async-await-Task-Actor with an event driven model?
  Can you feed your user events through an async sequence or Combine
  and then use for-await-in to spin an event loop?
  I think so --- but how do you get the events *into* the async sequence?

  Probably don't cover unsafe continuations (SE-0300) in TSPL,
  but maybe link to them?
-->

> 베타 소프트웨어:
>
> 이 도큐멘테이션은 개발중인 API 혹은 기술에 관한 예비 정보를 담고 있습니다. 이 정보는 바뀔 수 있으며, 이 도큐멘테이션에 따라 구현된 소프트웨어는 최종 운영 체제 소프트웨어를 이용해 테스트되어야 합니다.
>
>  [Apple 베타 소프트웨어](https://developer.apple.com/support/beta-software/) 사용에 관해 더 알아보기.

<!--
This source file is part of the Swift.org open source project

Copyright (c) 2014 - 2022 Apple Inc. and the Swift project authors
Licensed under Apache License v2.0 with Runtime Library Exception

See https://swift.org/LICENSE.txt for license information
See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
-->
