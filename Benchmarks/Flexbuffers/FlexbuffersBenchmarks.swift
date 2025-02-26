//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

/// Swift port of [Native-JSON Benchmark](https://github.com/miloyip/nativejson-benchmark)
/// NOTE: JSON Benchmarks where copied from https://github.com/swiftlang/swift-foundation/tree/main/Benchmarks/Benchmarks/JSON

/*
The MIT License (MIT)

Copyright (c) 2014 Milo Yip

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
*/

import Benchmark
import FlexBuffers
import func Benchmark.blackHole

import Foundation

// Use the types from Foundation
typealias _Data = Foundation.Data
typealias _URL = Foundation.URL
typealias _JSONEncoder = Foundation.JSONEncoder
typealias _JSONDecoder = Foundation.JSONDecoder

func path(forResource name: String) -> _URL? {
  guard let url = Bundle.module.url(forResource: name, withExtension: nil) else { return nil }
  return _URL(fileURLWithPath: url.path)
}

@MainActor
let benchmarks = {
  Benchmark.defaultConfiguration.maxIterations = 1_000_000_000
  Benchmark.defaultConfiguration.maxDuration = .seconds(3)
  Benchmark.defaultConfiguration.scalingFactor = .kilo
  Benchmark.defaultConfiguration.metrics = [.cpuTotal, .throughput]

  let canadaPath = path(forResource: "canada.json")
  let canadaData = try! _Data(contentsOf: canadaPath!)
  let canada = try! _JSONDecoder().decode(FeatureCollection.self, from: canadaData)

  let twitterPath = path(forResource: "twitter.json")
  let twitterData = try! _Data(contentsOf: twitterPath!)
  let twitter = try! _JSONDecoder().decode(TwitterArchive.self, from: twitterData)


  Benchmark("Canada-decodeFromJSON") { benchmark in
    let result = try _JSONDecoder().decode(FeatureCollection.self, from: canadaData)
    blackHole(result)
  }

  Benchmark("Canada-encodeToJSON") { benchmark in
    let data = try _JSONEncoder().encode(canada)
    blackHole(data)
  }

  Benchmark("Canada-manual-encodeToFlexbufferSharedKeys") { benchmark in
    let buf = createFlexBufferCanada(canada: canada, flags: .shareKeys)
    blackHole(buf)
  }

  Benchmark("Canada-manual-encodeToFlexbufferSharedKeysAndStrings") { benchmark in
    let buf = createFlexBufferCanada(canada: canada, flags: .shareKeysAndStrings)
    blackHole(buf)
  }

   // MARK: - Twitter

  Benchmark("Twitter-decodeFromJSON") { benchmark in
    let result = try _JSONDecoder().decode(TwitterArchive.self, from: twitterData)
    blackHole(result)
  }

  Benchmark("Twitter-encodeToJSON") { benchmark in
    let result = try _JSONEncoder().encode(twitter)
    blackHole(result)
  }

  Benchmark("Twitter-manual-encodeToFlexbufferSharedKeys") { benchmark in
    let buf = createFlexBufferTwitter(twitter: twitter)
    blackHole(buf)
  }

  Benchmark("Twitter-manual-encodeToFlexbufferSharedKeysAndStrings") { benchmark in
    let buf = createFlexBufferTwitter(twitter: twitter, flags: .shareKeysAndStrings)
    blackHole(buf)
  }
}

func writeFlexBufferArray(data: Data, url: URL) {
  let _url = url.deletingPathExtension().appendingPathExtension("bin")
  FileManager.default.createFile(atPath: _url.absoluteString, contents: Data(data))
}

@inline(__always)
func createFlexBufferTwitter(twitter: TwitterArchive, flags: BuilderFlag = .shareKeys) -> [UInt8] {
  var flx = FlexBuffersWriter(flags: flags)
  flx.map { outerMap in
    outerMap.vector(key: "statuses") { outerVector in
      for item in twitter.statuses {
        outerVector.map { sMap in
          sMap.add(uint64: item.id, key: "id")
          sMap.add(string: item.lang, key: "lang")
          sMap.add(string: item.text, key: "text")
          sMap.add(string: item.source, key: "source")
          sMap.map(key: "metadata") { metaMap in
            for (k, v) in item.metadata {
              metaMap.add(string: v, key: k)
            }
          }
          sMap.map(key: "user") { userMap in
            userMap.add(string: item.user.created_at, key: "created_at")
            userMap.add(string: item.user.screen_name, key: "screen_name")
            userMap.add(bool: item.user.default_profile, key: "default_profile")
            userMap.add(string: item.user.description, key: "description")
            userMap.add(uint64: item.user.favourites_count, key: "favourites_count")
            userMap.add(uint64: item.user.followers_count, key: "followers_count")
            userMap.add(uint64: item.user.friends_count, key: "friends_count")
            userMap.add(uint64: item.user.id, key: "id")
            userMap.add(string: item.user.lang, key: "lang")
            userMap.add(string: item.user.name, key: "name")
            userMap.add(string: item.user.profile_background_color, key: "profile_background_color")
            userMap.add(string: item.user.profile_background_image_url, key: "profile_background_image_url")
            userMap.add(string: item.user.profile_banner_url ?? "", key: "profile_banner_url")
            userMap.add(string: item.user.profile_image_url ?? "", key: "profile_image_url")
            userMap.add(bool: item.user.profile_use_background_image, key: "profile_use_background_image")
            userMap.add(uint64: item.user.statuses_count, key: "statuses_count")
            userMap.add(string: item.user.url ?? "", key: "url")
            userMap.add(bool: item.user.verified, key: "verified")
          }
          sMap.add(string: item.place ?? "", key: "place")
        }
      }
    }
  }
  flx.finish()
  return flx.sizedByteArray
}

@inline(__always)
func createFlexBufferCanada(canada: FeatureCollection, flags: BuilderFlag = .shareKeys) -> [UInt8] {
  var flx = FlexBuffersWriter(flags: flags)
  flx.map { writer in
    writer.add(string: canada.type.rawValue, key: "type")
    for feature in canada.features {
      writer.vector(key: "features") { vector in
        vector.add(string: feature.type.rawValue, key: "type")
        vector.map(key: "properties") { properties in
          for (k, v) in feature.properties {
            properties.add(string: v, key: k)
          }
        }

        vector.map(key: "geometry") { geometry in
          geometry.add(string: feature.geometry.type.rawValue, key: "type")
          geometry.vector(key: "coordinates") { coordinates in
            for coordinate in feature.geometry.coordinates {
              coordinates.vector { vec in
                for coord in coordinate {
                  vec.add(double: coord.longitude, key: "longitude")
                  vec.add(double: coord.latitude, key: "latitude")
                }
              }
            }
          }
        }
      }
    }
  }
  flx.finish()
  return flx.sizedByteArray
}
