package main

import (
	"fmt"
	"mime"
	"path/filepath"
)

func main() {
	types := map[string]string{
		".arw": "image/x-sony-arw",
		".cr2": "image/x-canon-cr2",
	}
	for ext, typ := range types {
		mime.AddExtensionType(ext, typ)
	}
	
	fmt.Println("ARW:", mime.TypeByExtension(".ARW"))
	fmt.Println("arw:", mime.TypeByExtension(".arw"))
	fmt.Println("filepath.Ext:", filepath.Ext("LZJ06810.ARW"))
}
