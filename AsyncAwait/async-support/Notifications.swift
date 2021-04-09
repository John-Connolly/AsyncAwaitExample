//
//  Notifications.swift
//  AsyncNotifications
//
//  Created by John Connolly on 2021-04-04.
//

import Foundation
import _Concurrency
import Swift

extension NotificationCenter {
    func notifications(of name: Notification.Name, on object: AnyObject? = nil) -> Notifications {
        return Notifications(name: name, object: object, center: self)
    }
    
    struct Notifications: AsyncSequence {
        let name: Notification.Name
        let object: AnyObject?
        let center: NotificationCenter
        
        typealias Element = Notification
        func makeAsyncIterator() -> Iterator {
            Iterator(center: center, name: name, object: object)
        }
        
        final class Iterator : AsyncIteratorProtocol {
            let name: Notification.Name
            let object: AnyObject?
            let center: NotificationCenter
            
            init(center: NotificationCenter, name: Notification.Name, object: AnyObject? = nil) {
                self.name = name
                self.object = object
                self.center = center
            }
            
            let continuation = YieldingContinuation<Notification, Never>()

            var observationToken: Any?
            func next() async -> Notification? {
                DispatchQueue.main.async {
                    self.observationToken = self.center.addObserver(forName: self.name, object: self.object, queue: nil) {
                        // NotificationCenter's behavior is to drop if nothing is registered to receive, so ignore the return value. Other implementations may choose to provide a buffer.

                        let _ = self.continuation.yield($0)
                    }
                }

                return await continuation.next()
            }
        }
    }
}

extension Notification.Name {
    static let didReceiveData = Notification.Name("didReceiveData")
}

extension AsyncSequence {
    func collect() async throws -> [Element] {
        var buffer = [Element]()
        for try await element in self {
            buffer.append(element)
        }
        return buffer
    }
}
