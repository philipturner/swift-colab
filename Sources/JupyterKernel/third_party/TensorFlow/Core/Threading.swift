// Copyright 2019 The TensorFlow Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
  import Darwin
#elseif os(Windows)
  import ucrt
  import WinSDK
#else
  import Glibc
#endif

/// A portable mutex for synchronization of a shared resource.
class Mutex {
  #if os(Windows)
    typealias MutexType = SRWLOCK
  #else
    typealias MutexType = pthread_mutex_t
  #endif

  var _mutex: MutexType

  init() {
    _mutex = MutexType()
    #if os(Windows)
      InitializeSRWLock(&_mutex)
    #else
      pthread_mutex_init(&_mutex, nil)
    #endif
  }

  deinit {
    #if os(Windows)
      // SRWLOCKs do not need explicit destruction
    #else
      pthread_mutex_destroy(&_mutex)
    #endif
  }

  // Acquire the mutex.
  //
  // Calling this function will block until it is safe to access the resource
  // that the mutex is protecting, locking the mutex indicating ownership of
  // the shared resource.
  //
  // Returns 0 on success.
  func acquire() -> Int32 {
    #if os(Windows)
      AcquireSRWLockExclusive(&_mutex)
      return 0
    #else
      return pthread_mutex_lock(&_mutex)
    #endif
  }

  // Release the mutex.
  //
  // Calling this function unlocks the mutex, relinquishing control of the
  // shared resource.
  //
  // Returns 0 on success.
  func release() -> Int32 {
    #if os(Windows)
      ReleaseSRWLockExclusive(&_mutex)
      return 0
    #else
      return pthread_mutex_unlock(&_mutex)
    #endif
  }
}
