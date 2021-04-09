//
//  ViewController.swift
//  AsyncAwait
//
//  Created by John Connolly on 2021-04-06.
//

import UIKit
import _Concurrency
import Swift

@MainActor
class ViewController: UIViewController {

    @IBOutlet weak var tableview: UITableView!
    @IBOutlet weak var searchbar: UISearchBar!
    var viewModel = AlbumViewModel()

    @asyncHandler
    override func viewDidLoad() {
        super.viewDidLoad()
        tableview.delegate = self
        tableview.dataSource = self
        tableview.register(UINib(nibName: "AlbumTableViewCell", bundle: nil), forCellReuseIdentifier: "cell")

        observeSearchBarText()

        do {
            try await viewModel.loadAlbums()
            tableview.reloadData()
        } catch {
            print(error)
        }
    }


    @asyncHandler
    func observeSearchBarText() {
        let textStream = searchbar.searchTextField.textSequence()
            .map(\.object)
            .map { $0 as! UITextField }
            .map(\.text)

        for await text in textStream {
            viewModel.search(with: text ?? "")
            tableview.reloadData()
        }


    }

}

extension ViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.albums.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableview.dequeueReusableCell(withIdentifier: "cell") as! AlbumTableViewCell
        cell.titleLabel.text = viewModel.albums[indexPath.row].title
        cell.imageview.image = viewModel.albums[indexPath.row].image
        return cell
    }
}

extension UITextField {

    func textSequence() -> NotificationCenter.Notifications  {
        return NotificationCenter.default.notifications(of: UITextField.textDidChangeNotification, on: self)

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

    enum Search {
        case searching(String)
        case notSearching
    }

    var search = Search.notSearching
    private var _albums: [Album] = []

    var albums: [Album] {
        switch search {
        case let .searching(text):
            return _albums.filter { $0.title.starts(with: text.lowercased()) }
        case .notSearching:
            return _albums
        }
    }

    func loadAlbums() async throws {
        let url = URL(string: "https://jsonplaceholder.typicode.com/photos")!
        let data = try await request(url: url)
        let albums = try JSONDecoder().decode([AlbumApiResource].self, from: data).prefix(30)
        self._albums = try await loadImagesOnebyOne(from: Array(albums))
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

    func search(with text: String) {
        search = text != "" ? .searching(text) : .notSearching
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
