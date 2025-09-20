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
