package main

import (
	"bytes"
	"fmt"
	"image"
	_ "image/jpeg"
	_ "image/png"
	"io"
	"os"
)

func isRaw(data []byte) bool {
	if len(data) < 16 {
		return false
	}
	if (data[0] == 'I' && data[1] == 'I' && data[2] == '*') ||
		(data[0] == 'M' && data[1] == 'M' && data[2] == 0x00 && data[3] == '*') {
		return true
	}
	return false
}

func main() {
	f, err := os.Open("/Volumes/detail/my photo/2023年/10030220/LZJ06810.ARW")
	if err != nil {
		panic(err)
	}
	defer f.Close()

	buf := &bytes.Buffer{}
	r := io.TeeReader(f, buf)

	_, _, err = image.DecodeConfig(r)
	if err != nil {
		data := buf.Bytes()
		fmt.Printf("DecodeConfig failed. bytes read: %d\n", len(data))
		isRawRes := isRaw(data)
		fmt.Printf("isRaw: %v\n", isRawRes)
	}
}
