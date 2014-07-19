Pod::Spec.new do |s|
  s.name         = "AAPLAdvancedCollectionView"
  s.version      = "1.0.7"
  s.summary      = "Advanced User Interfaces Using Collection View"
  s.description  = <<-DESC
                   This example demonstrates code factoring approaches to UICollectionViewDataSource
                   that allow developers to compose complex and rich data models. In addition,
                   the framework features a sophisticated custom UICollectionViewLayout that
                   with pinning headers, global headers, and loading placeholders.
                   DESC
  s.homepage     = "https://developer.apple.com/wwdc/resources/sample-code/"
  s.license      = { :type => "Apple Sample Code", :file => "LICENSE.txt" }
  s.authors      = "Apple", "Zachary Waldowski"
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/zwaldowski/AAPLAdvancedCollectionView.git", :tag => "v#{s.version}" }
  s.source_files = "AdvancedCollectionView/Framework/**/*.{h,m}"
  s.framework    = "UIKit"
  s.requires_arc = true
end
