const fs = require('fs');
const path = require('path');

function walkDir(dir, callback) {
  fs.readdirSync(dir).forEach(f => {
    let dirPath = path.join(dir, f);
    let isDirectory = fs.statSync(dirPath).isDirectory();
    isDirectory ? walkDir(dirPath, callback) : callback(path.join(dir, f));
  });
}

walkDir('src/pages', function(filePath) {
  if (filePath.endsWith('.jsx')) {
    let content = fs.readFileSync(filePath, 'utf8');
    let original = content;
    content = content.replace(/<Loader2.*?size=\{32\}.*?\/>/g, '<div className="skeuo-loader"></div>');
    content = content.replace(/<Loader2.*?size=\{(14|16|18|20|24)\}.*?\/>/g, '<div className="skeuo-loader sm"></div>');
    if (content !== original) {
      fs.writeFileSync(filePath, content);
      console.log('Updated', filePath);
    }
  }
});
