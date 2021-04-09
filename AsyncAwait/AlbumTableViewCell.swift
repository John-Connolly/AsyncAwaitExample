//
//  AlbumTableViewCell.swift
//  AsyncAwait
//
//  Created by John Connolly on 2021-04-08.
//

import UIKit
import Swift

class AlbumTableViewCell: UITableViewCell {

    @IBOutlet weak var imageview: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!


    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
