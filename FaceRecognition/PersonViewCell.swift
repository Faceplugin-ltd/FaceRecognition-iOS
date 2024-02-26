

import UIKit

protocol PersonViewCellDelegate: AnyObject {
    func didPersonDelete(_ cell: UITableViewCell)
}

class PersonViewCell: UITableViewCell {
    
    @IBOutlet weak var nameLbl: UILabel!
    @IBOutlet weak var faceImage: UIImageView!
    
    weak var delegate: PersonViewCellDelegate?
    var indexPath: IndexPath?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    @IBAction func delete_clicked(_ sender: Any) {
        delegate?.didPersonDelete(self)
    }
    
}
