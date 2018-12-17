
import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .magenta
        
        NetworkClient.shared.getMedia(at: nil) { items, error in
            print("Fetched items: \(items)")
        }
    }

}

