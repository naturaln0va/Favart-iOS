
import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .magenta
        
        let prettyLabel = UILabel()
        prettyLabel.translatesAutoresizingMaskIntoConstraints = false
        prettyLabel.font = UIFont(name: "Chalkduster", size: 64)
        prettyLabel.textColor = .green
        prettyLabel.text = "Kool App"
        
        view.addSubview(prettyLabel)
        
        NSLayoutConstraint.activate([
            prettyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            prettyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

}

