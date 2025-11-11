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
import FlatBuffers
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

func bin(name: String) -> _Data {
  let path = path(forResource: name)
  return try! _Data(contentsOf: path!)
}

func write(data: Data, url: URL) {
  let _url = url.deletingPathExtension().appendingPathExtension("bin")
  print(_url)
  FileManager.default.createFile(atPath: _url.absoluteString, contents: Data(data))
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

  let canadaSharedKeyBin: FlexBuffers.ByteBuffer = ByteBuffer(data: bin(name: "canada-sharedKeys.bin"))
  let canadaSharedKeysAndStringsBin: FlexBuffers.ByteBuffer = ByteBuffer(data: bin(name: "canada-sharedKeysAndStrings.bin"))
  var canadaFlatbuffer: FlatBuffers.ByteBuffer = ByteBuffer(data: bin(name: "canada-flatbuffer.bin"))

  // MARK: DECODING

  Benchmark("canada-decode-JSON") { benchmark in
    let result = try _JSONDecoder().decode(FeatureCollection.self, from: canadaData)
    blackHole(result)
  }

  Benchmark("canada-decode-manual-FlexbufferSharedKeys") { benchmark in
    let buf = try! getRoot(buffer: canadaSharedKeyBin)
    let name = buf!.map!["features"]!.vector?[0]!.map!["properties"]!.map!["name"]!.cString ?? ""
    let v1 = buf!.map!["features"]!.vector?[0]!.map!["geometry"]!.map!["coordinates"]!.vector?[0]!.vector?[0]!.typedVector?[0]!.double
    let v2 = buf!.map!["features"]!.vector?[0]!.map!["geometry"]!.map!["coordinates"]!.vector?[0]!.vector?[0]!.typedVector?[1]?.double
    blackHole(name + String(describing: v1) + String(describing: v2))
  }

  Benchmark("canada-decode-manual-FlexbufferSharedKeysAndStrings") { benchmark in
    let buf = try! getRoot(buffer: canadaSharedKeysAndStringsBin)
    let name = buf!.map!["features"]!.vector?[0]!.map!["properties"]!.map!["name"]!.cString ?? ""
    let v1 = buf!.map!["features"]!.vector?[0]!.map!["geometry"]!.map!["coordinates"]!.vector?[0]!.vector?[0]!.typedVector?[0]!.double
    let v2 = buf!.map!["features"]!.vector?[0]!.map!["geometry"]!.map!["coordinates"]!.vector?[0]!.vector?[0]!.typedVector?[1]?.double
    blackHole(name + String(describing: v1) + String(describing: v2))
  }

  Benchmark("canada-decode-Flatbuffer") { benchmark in
    let buf: Geo_FeatureCollection = try! getCheckedRoot(byteBuffer: &canadaFlatbuffer)
    let name = buf.type
    let coords = buf.features[0].geometry?.coordinates[0].coords[0]
    blackHole(String(describing: name) + String(describing: coords))
  }

  Benchmark("canada-decode-FlatbufferMutable") { benchmark in
    let buf: Geo_FeatureCollection = try! getCheckedRoot(byteBuffer: &canadaFlatbuffer)
    let name = buf.type
    let coords = buf.features[0].geometry?.coordinates[0]
    let lat = coords?.mutableCoords[0].latitude
    let long = coords?.mutableCoords[0].longitude
    blackHole(String(describing: name) + String(describing: lat) + String(describing: long))
  }

  // MARK: ENCODING

  Benchmark("canada-encode-JSON") { benchmark in
    let data = try _JSONEncoder().encode(canada)
    blackHole(data)
  }

  Benchmark("canada-encode-Flatbuffer") { benchmark in
    blackHole(createFlatBufferCanada(canada: canada))
  }

  Benchmark("canada-encode-manual-FlexbufferSharedKeys") { benchmark in
    let buf = createFlexBufferCanada(canada: canada, flags: .shareKeys)
    blackHole(buf)
  }

  Benchmark("canada-encode-manual-FlexbufferSharedKeysAndStrings") { benchmark in
    let buf = createFlexBufferCanada(canada: canada, flags: .shareKeysAndStrings)
    blackHole(buf)
  }

  // MARK: - Twitter

  let twitterPath = path(forResource: "twitter.json")
  let twitterData = try! _Data(contentsOf: twitterPath!)
  let twitter = try! _JSONDecoder().decode(TwitterArchive.self, from: twitterData)

  let twitterSharedKeyBin: FlexBuffers.ByteBuffer = ByteBuffer(data: bin(name: "twitter-sharedKeys.bin"))
  let twittersharedKeysAndStringsBin: FlexBuffers.ByteBuffer = ByteBuffer(data: bin(name: "twitter-sharedKeysAndStrings.bin"))
  var twitterFlatbuffer: FlatBuffers.ByteBuffer = ByteBuffer(data: bin(name: "twitter-flatbuffers.bin"))
  // MARK: DECODING

  Benchmark("twitter-decode-JSON") { benchmark in
    let result: TwitterArchive = try _JSONDecoder().decode(TwitterArchive.self, from: twitterData)
    let v = result.statuses[0].user.name
    blackHole(v)
  }

  Benchmark("twitter-decode-manual-FlexbufferSharedKeys") { benchmark in
    let buf = try! getRoot(buffer: twitterSharedKeyBin)
    let v = buf!.map!["statuses"]!.vector?[0]!.map!["user"]!.map!["name"]!.cString
    blackHole(v)
  }

  Benchmark("twitter-decode-manual-FlexbufferSharedKeysAndStrings") { benchmark in
    let buf = try! getRoot(buffer: twittersharedKeysAndStringsBin)
    let v = buf!.map!["statuses"]!.vector?[0]!.map!["user"]!.map!["name"]!.cString
    blackHole(v)
  }

  Benchmark("twitter-decode-Flatbuffer") { benchmark in
    let buf: Twitter_TwitterArchive = try! getCheckedRoot(byteBuffer: &twitterFlatbuffer)
    blackHole(buf.statuses[0].text)
  }

  // MARK: ENCODING

  Benchmark("twitter-encode-JSON") { benchmark in
    let result = try _JSONEncoder().encode(twitter)
    blackHole(result)
  }

  Benchmark("twitter-encode-Flatbuffer") { benchmark in
    blackHole(createFlatBufferTwitter(twitter: twitter))
  }

  Benchmark("twitter-encode-manual-FlexbufferSharedKeys") { benchmark in
    let buf = createFlexBufferTwitter(twitter: twitter)
    blackHole(buf)
  }

  Benchmark("twitter-encode-manual-FlexbufferSharedKeysAndStrings") { benchmark in
    let buf = createFlexBufferTwitter(twitter: twitter, flags: .shareKeysAndStrings)
    blackHole(buf)
  }
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
        vector.map { innerMap in
          innerMap.add(string: feature.type.rawValue, key: "type")
          innerMap.map(key: "properties") { properties in
            for (k, v) in feature.properties {
              properties.add(string: v, key: k)
            }
          }

          innerMap.map(key: "geometry") { geometry in
            geometry.add(string: feature.geometry.type.rawValue, key: "type")
            geometry.vector(key: "coordinates") { coordinates in
              for coordinate in feature.geometry.coordinates {
                coordinates.vector { vec in
                  for coord in coordinate {
                    vec.createFixed(vector: [coord.longitude, coord.latitude])
                  }
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

@inline(__always)
func createFlatBufferCanada(canada: FeatureCollection) -> [UInt8] {
  var builder = FlatBufferBuilder(initialSize: 1024, serializeDefaults: false)

  let featureCollectionOffset = builder.create(string: ObjType.featureCollection.rawValue)
  let featureOffset = builder.create(string: ObjType.feature.rawValue)
  let polygonOffset = builder.create(string: ObjType.polygon.rawValue)

  var offsets: [Offset] = []
  for feature in canada.features {
    var coordList: [Offset] = []
    for coord in feature.geometry.coordinates {
      var structs: [Geo_Coordinate] = []
      for coordinate in coord {
        structs.append(Geo_Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude))
      }

      coordList.append(Geo_CoordinateList.createCoordinateList(&builder, coordsVectorOffset: builder.createVector(ofStructs: structs)))
    }

    var propertiesOffsets: [Offset] = []
    for (k, v) in feature.properties {
      let key = builder.create(string: k)
      let value = builder.create(string: v)
      propertiesOffsets.append(Geo_PropertyEntry.createPropertyEntry(&builder, keyOffset: key, valueOffset: value))
    }

    let geoOffset = Geo_Geometry.createGeometry(&builder, typeOffset: polygonOffset, coordinatesVectorOffset: builder.createVector(ofOffsets: coordList))
    let propertiesOffset = builder.createVector(ofOffsets: propertiesOffsets)

    offsets.append(Geo_Feature.createFeature(&builder, typeOffset: featureOffset, propertiesVectorOffset: propertiesOffset, geometryOffset: geoOffset))
  }

  let featureVectorOffset = builder.createVector(ofOffsets: offsets)
  let root = Geo_FeatureCollection.createFeatureCollection(
    &builder,
    typeOffset: featureCollectionOffset,
    featuresVectorOffset: featureVectorOffset
  )

  builder.finish(offset: root)
  return builder.sizedByteArray
}

@inline(__always)
func createFlatBufferTwitter(twitter: TwitterArchive) -> [UInt8] {
  var builder = FlatBufferBuilder(initialSize: 1024, serializeDefaults: false)

  var statusesOffsets: [Offset] = []
  for status in twitter.statuses {

    let langoffset = builder.create(string: status.lang)
    let textOffset = builder.create(string: status.text)
    let sourceOffset = builder.create(string: status.source)
    let placeOffset = builder.create(string: status.place)

    let user = status.user

    let createdAt = builder.create(string: user.created_at)
    let description = builder.create(string: user.description)
    let lang = builder.create(string: user.lang)
    let name = builder.create(string: user.name)
    let profileBackgroundColor = builder.create(string: user.profile_background_color)
    let profileBackgroundImageUrl = builder.create(string: user.profile_background_image_url)
    let profileBannerUrl = builder.create(string: user.profile_banner_url)
    let profileImageUrl = builder.create(string: user.profile_image_url)
    let screenName = builder.create(string: user.screen_name)
    let url = builder.create(string: user.url)

    var metadata: [Offset] = []
    for (key, value) in status.metadata {
      let keyOffset = builder.create(string: String(describing: key))
      let valueOffset = builder.create(string: String(describing: value))
      metadata.append(
        Twitter_MetadataEntry.createMetadataEntry(
          &builder,
          keyOffset: keyOffset,
          valueOffset: valueOffset
        )
      )
    }

    let metadataVectorOffset = builder.createVector(ofOffsets: metadata)

    let userOffset = Twitter_User.createUser(
      &builder,
      createdAtOffset: createdAt,
      defaultProfile: user.default_profile,
      descriptionOffset: description,
      favouritesCount: user.favourites_count,
      followersCount: user.followers_count,
      friendsCount: user.friends_count,
      id: user.id,
      langOffset: lang,
      nameOffset: name,
      profileBackgroundColorOffset: profileBackgroundColor,
      profileBackgroundImageUrlOffset: profileBackgroundImageUrl,
      profileBannerUrlOffset: profileBannerUrl,
      profileImageUrlOffset: profileImageUrl,
      profileUseBackgroundImage: user.profile_use_background_image,
      screenNameOffset: screenName,
      statusesCount: user.statuses_count,
      urlOffset: url,
      verified: user.verified
    )

    statusesOffsets.append(
      Twitter_Status.createStatus(
        &builder,
        id: status.id,
        langOffset: langoffset,
        textOffset: textOffset,
        sourceOffset: sourceOffset,
        metadataVectorOffset: metadataVectorOffset,
        userOffset: userOffset,
        placeOffset: placeOffset
      )
    )
  }

  let offset = builder.createVector(ofOffsets: statusesOffsets)
  let root = Twitter_TwitterArchive.createTwitterArchive(&builder, statusesVectorOffset: offset)
  builder.finish(offset: root)
  return builder.sizedByteArray
}
