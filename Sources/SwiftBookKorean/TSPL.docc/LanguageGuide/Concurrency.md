#  동시성 (Concurrency)

비동기 연산을 수행합니다.

Swift는 비동기 및 병렬 코드 작성 지원을 탑재하고 있습니다.
*비동기 코드 (Asynchronous code)*는 일시 정지된 후 나중에 재개될 수 있습니다.
다만 코드의 여러 부분이 동시에 실행되지는 않습니다.
코드를 일시 정지한 후 재개함으로써, 네트워크로부터 데이터를 불러오거나 파일을 파싱하는 등의 오래 지속되는 연산을 수행하는 동시에 
UI를 업데이트하는 등의 단기적 연산을 이어나갈 수 있습니다.
*병렬 코드 (Parallel code)*란 여러 코드가 동시에 실행되는 것을 가리킵니다.
예를 들어, 4코어 프로세서를 탑재한 컴퓨터는 코어 하나당 한 가지 작업을 수행함으로써 동시에 네 가지 코드를 실행할 수 있습니다.
병렬 혹은 비동기 코드를 사용하는 프로그램은 여러 연산을 한 번에 수행하고, 외부 시스템을 기다리는 중인 연산을 일시 정지할 수 있습니다.
이러한 흔히 나타나는 비동기와 병렬 코드의 결합을 가리킬 때 이 장의 나머지에서는 *동시성*이라는 용어를 사용합니다.

병렬 혹은 비동기 코드로 얻는 스케줄링 유연성에는 복잡성 증가라는 대가가 따릅니다.
동시성 코드를 작성할 때 우리는 어떤 코드가 동시에 실행될지 혹은 어떤 순서로 코드가 실행될지 미리 알 수 없습니다.
동시성 코드에서 흔한 문제 중 하나는
여러 코드가 한 가지 가변 상태에 동시에 접근하려고 할 때 발생하는데,
이를 *데이터 경합 (data race)*이라고 합니다.
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

*비동기 함수 (asynchronous function)* 또는 *비동기 메서드 (asynchronous method)*는
실행 도중에 일시 정지될 수 있는 특별한 종류의 함수나 메서드입니다.
이는 완료될 때까지 실행되거나, 에러를 던지거나, 아예 반환하지 않는
일반적인 동기 함수 및 메서드와는 대조적입니다.
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
비동기 메서드 안에서 실행 흐름이 일시 정지될 수 있는 것은 *다른 비동기 메서드를 호출할 때 뿐*입니다.
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
이를 *스레드 양보 (yielding the thread)*라고도 하는데,
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
다른 접근법으로는 *비동기 시퀀스 (asynchronous sequence)*를 사용하여
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

*작업 (task)*은 프로그램의 일부로, 비동기적으로 실행될 수 있는 일의 단위입니다.
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
이 접근법을 *구조화된 동시성 (structured concurrency)*이라고 합니다.
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
