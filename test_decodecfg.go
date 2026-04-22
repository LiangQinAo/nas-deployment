package main

import (
	"bytes"
	"fmt"
	"image"
	_ "image/jpeg"
	"io"
	"os"
)

func extractRawPreview(in io.Reader) ([]byte, error) {
	data := make([]byte, 2*1024*1024)
	n, _ := io.ReadFull(in, data)
	data = data[:n]
	start := bytes.Index(data, []byte{0xff, 0xd8})
	if start != -1 {
		end := bytes.LastIndex(data[start:], []byte{0xff, 0xd9})
		if end != -1 {
			return data[start : start+end+2], nil
		}
	}
	return nil, fmt.Errorf("no preview found")
}

func main() {
	f, err := os.Open("/Volumes/detail/my photo/2023年/10030220/LZJ06810.ARW")
	if err != nil {
		panic(err)
	}
	defer f.Close()

	preview, err := extractRawPreview(f)
	if err != nil {
		panic(err)
	}
	
	config, format, err := image.DecodeConfig(bytes.NewReader(preview))
	if err != nil {
		fmt.Printf("DecodeConfig ERROR: %v\n", err)
	} else {
		fmt.Printf("DecodeConfig SUCCESS: %s %dx%d\n", format, config.Width, config.Height)
	}
}
