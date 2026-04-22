package main

import (
	"bytes"
	"fmt"
	"io"
	"os"
	exif "github.com/dsoprea/go-exif/v3"
	exifcommon "github.com/dsoprea/go-exif/v3/common"
	"github.com/disintegration/imaging"
)

func getEmbeddedThumbnail(in io.Reader) ([]byte, error) {
	buf := &bytes.Buffer{}
	r := io.TeeReader(in, buf)
	offset := 0
	offsets := []int{12, 30}
	head := make([]byte, 0xffff)
	_, err := r.Read(head)
	if err != nil {
		return nil, err
	}
	for _, offset = range offsets {
		if _, err = exif.ParseExifHeader(head[offset:]); err == nil {
			break
		}
	}
	if err != nil {
		return nil, err
	}
	im, err := exifcommon.NewIfdMappingWithStandard()
	if err != nil {
		return nil, err
	}
	_, index, err := exif.Collect(im, exif.NewTagIndex(), head[offset:])
	if err != nil {
		return nil, err
	}
	ifd := index.RootIfd.NextIfd()
	if ifd == nil {
		return nil, exif.ErrNoThumbnail
	}
	thm, err := ifd.Thumbnail()
	return thm, err
}

func extractRawPreview(in io.Reader) ([]byte, error) {
	data := make([]byte, 2*1024*1024)
	n, _ := io.ReadFull(in, data)
	data = data[:n]
	preview, err := getEmbeddedThumbnail(bytes.NewReader(data))
	if err == nil {
		return preview, nil
	}
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
