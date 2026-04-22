package main

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"github.com/disintegration/imaging"
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
		fmt.Printf("ERROR extraction: %v\n", err)
		return
	}
	fmt.Printf("SUCCESS: Extracted %d bytes\n", len(preview))

	img, err := imaging.Decode(bytes.NewReader(preview), imaging.AutoOrientation(true))
	if err != nil {
		fmt.Printf("ERROR decode: %v\n", err)
		return
	}
	fmt.Printf("SUCCESS: Decoded image %dx%d\n", img.Bounds().Dx(), img.Bounds().Dy())
}
