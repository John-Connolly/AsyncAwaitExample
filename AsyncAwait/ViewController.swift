//
//  ViewController.swift
//  AsyncAwait
//
//  Created by John Connolly on 2021-04-06.
//

import UIKit
import _Concurrency

@MainActor
class ViewController: UIViewController {

    @IBOutlet weak var tableview: UITableView!
    let viewModel = AlbumViewModel()

    @asyncHandler
    override func viewDidLoad() {
        super.viewDidLoad()
        tableview.delegate = self
        tableview.dataSource = self

        do {
            try await viewModel.loadAlbums()
            tableview.reloadData()
        } catch {

        }
    }


}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.albums.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = viewModel.albums[indexPath.row].title
        return cell
    }


}

struct AlbumApiResource: Codable {
    let albumId: Int
    let id: Int
    let title: String
    let url: URL
    let thumbnailUrl: URL
}

struct Album {
    let title: String
    let image: UIImage
}


final class AlbumViewModel {

    var albums: [Album] = []


    func loadAlbums() async throws {
        let url = URL(string: "https://jsonplaceholder.typicode.com/photos")!
        let data = try await request(url: url)
        let albums = try JSONDecoder().decode([AlbumApiResource].self, from: data).prefix(30)
        self.albums = try await loadImagesOnebyOne(from: Array(albums))
    }


    func loadImagesConcurrently(from apiResources: [AlbumApiResource]) async throws -> [Album] {
        return try await Task.withGroup(resultType: Album.self) { group -> [Task.Group<Album>.Element] in
            for apiResource in apiResources {
                await group.add {
                    let data = try await request(url: apiResource.thumbnailUrl)
                    let image = UIImage(data: data)
                    return Album(title: apiResource.title, image: image ?? UIImage())
                }
            }
            return try await group.collect()
        }
    }

    func loadImagesOnebyOne(from apiResources: [AlbumApiResource]) async throws -> [Album] {
        var albums: [Album] = []
        for apiResource in apiResources {
            let data = try await request(url: apiResource.thumbnailUrl)
            let image = UIImage(data: data)
            albums.append(Album(title: apiResource.title, image: image ?? UIImage()))
        }

        return albums
    }


//    func loadImages(from albums: [AlbumApiResource]) async throws -> [Album] {
//
//        var albums: [Album] = []
//        try await withTaskGroup(of: Album.self) { group in
//
//            for apiResource in albums {
//                group.spawn {
//                    let data = try await makeApiRequest(url: album.thumbnailUrl)
//                    let image = UIImage(data: data)
//                    return Album(title: apiResource.title, image: image)
//                }
//            }
//
//            for await album in group {
//                albums.append(album)
//            }
//
//        }
//        return albums
//
//    }

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

struct NetworkError: Error { }

func request(url: URL) async throws -> Data {
  return try await withUnsafeThrowingContinuation { (continuation) in
    URLSession.shared.dataTask(with: url) { (data, response, error) in
      switch (data, error) {
      case let (_, error?):
        return continuation.resume(throwing: error)
      case let (data?, _):
        return continuation.resume(returning: data)
      case (nil, nil):
        return continuation.resume(throwing: NetworkError())
      }
    }
    .resume()
  }
}
