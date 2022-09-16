//
//  OpenCVWrapper.mm
//  VisionCameraExample
//
//  Created by Matias Fitó Reussi on 15/09/2022.
//

#import "OpenCVWrapper.h"

#import <opencv2/opencv.hpp>

#include <iostream>
#import<UIKit/UIKit.h>

using namespace std;
using namespace cv;

@implementation OpenCVWrapper

+ (NSString *)openCVVersionString {
  return [NSString stringWithFormat:@"OpenCV Version %s",  CV_VERSION];
}
#pragma mark Public

+ (UIImage *)toGray:(UIImage *)source {
  cout << "OpenCV: ";
  return [OpenCVWrapper _imageFrom:[OpenCVWrapper _grayFrom:[OpenCVWrapper _matFrom:source]]];
}

+ (UIImage *)processImageWithOpenCV:(UIImage*)inputImage {
  Mat srcMat = [OpenCVWrapper _matFrom:inputImage];
  vector<vector<cv::Point>> squares;
  findSquares(srcMat, squares);
  
  // Draw all detected squares
    cv::Mat src_squares = srcMat.clone();
    for (size_t i = 0; i < squares.size(); i++)
    {
        const cv::Point* p = &squares[i][0];
        int n = (int)squares[i].size();
        cv::polylines(src_squares, &p, &n, 1, true, cv::Scalar(0, 255, 0), 2, 16);
    }
    cv::imwrite("out_squares.jpg", src_squares);
    cv::imshow("Squares", src_squares);

    std::vector<cv::Point> largest_square;
    findLargestSquare(squares, largest_square);

    // Draw circles at the corners
    for (size_t i = 0; i < largest_square.size(); i++ )
        cv::circle(srcMat, largest_square[i], 4, cv::Scalar(0, 0, 255), cv::FILLED);
    cv::imwrite("out_corners.jpg", srcMat);

    cv::imshow("Corners", srcMat);
    cv::waitKey(0);
  
  return [OpenCVWrapper _imageFrom: srcMat];
}


#pragma mark Private

int thresh = 50, N = 11;
const char* wndname = "Square Detection Demo";


void findLargestSquare(const std::vector<std::vector<cv::Point> >& squares,
                       std::vector<cv::Point>& biggest_square)
{
    if (!squares.size())
    {
        std::cout << "findLargestSquare !!! No squares detect, nothing to do." << std::endl;
        return;
    }

    int max_width = 0;
    int max_height = 0;
    int max_square_idx = 0;
    for (size_t i = 0; i < squares.size(); i++)
    {
        // Convert a set of 4 unordered Points into a meaningful cv::Rect structure.
        cv::Rect rectangle = cv::boundingRect(cv::Mat(squares[i]));

        //std::cout << "find_largest_square: #" << i << " rectangle x:" << rectangle.x << " y:" << rectangle.y << " " << rectangle.width << "x" << rectangle.height << endl;

        // Store the index position of the biggest square found
        if ((rectangle.width >= max_width) && (rectangle.height >= max_height))
        {
            max_width = rectangle.width;
            max_height = rectangle.height;
            max_square_idx = i;
        }
    }

    biggest_square = squares[max_square_idx];
}


static void findSquares( const Mat& image, vector<vector<cv::Point> >& squares )
{
    squares.clear();
    Mat pyr, timg, gray0(image.size(), CV_8U), gray;
    // down-scale and upscale the image to filter out the noise
    pyrDown(image, pyr, cv::Size(image.cols/2, image.rows/2));
    pyrUp(pyr, timg, image.size());
    vector<vector<cv::Point> > contours;
    // find squares in every color plane of the image
    for( int c = 0; c < 3; c++ )
    {
        int ch[] = {c, 0};
        mixChannels(&timg, 1, &gray0, 1, ch, 1);
        // try several threshold levels
        for( int l = 0; l < N; l++ )
        {
            // hack: use Canny instead of zero threshold level.
            // Canny helps to catch squares with gradient shading
            if( l == 0 )
            {
                // apply Canny. Take the upper threshold from slider
                // and set the lower to 0 (which forces edges merging)
                Canny(gray0, gray, 0, thresh, 5);
                // dilate canny output to remove potential
                // holes between edge segments
                dilate(gray, gray, Mat(), cv::Point(-1,-1));
            }
            else
            {
                // apply threshold if l!=0:
                //     tgray(x,y) = gray(x,y) < (l+1)*255/N ? 255 : 0
                gray = gray0 >= (l+1)*255/N;
            }
            // find contours and store them all as a list
            findContours(gray, contours, RETR_LIST, CHAIN_APPROX_SIMPLE);
            vector<cv::Point> approx;
            // test each contour
            for( size_t i = 0; i < contours.size(); i++ )
            {
                // approximate contour with accuracy proportional
                // to the contour perimeter
                approxPolyDP(contours[i], approx, arcLength(contours[i], true)*0.02, true);
                // square contours should have 4 vertices after approximation
                // relatively large area (to filter out noisy contours)
                // and be convex.
                // Note: absolute value of an area is used because
                // area may be positive or negative - in accordance with the
                // contour orientation
                if( approx.size() == 4 &&
                    fabs(contourArea(approx)) > 1000 &&
                    isContourConvex(approx) )
                {
                    double maxCosine = 0;
                    for( int j = 2; j < 5; j++ )
                    {
                        // find the maximum cosine of the angle between joint edges
                        double cosine = fabs(angle(approx[j%4], approx[j-2], approx[j-1]));
                        maxCosine = MAX(maxCosine, cosine);
                    }
                    // if cosines of all angles are small
                    // (all angles are ~90 degree) then write quandrange
                    // vertices to resultant sequence
                    if( maxCosine < 0.3 )
                        squares.push_back(approx);
                }
            }
        }
    }
}


static double angle( cv::Point pt1, cv::Point pt2, cv::Point pt0 )
{
    double dx1 = pt1.x - pt0.x;
    double dy1 = pt1.y - pt0.y;
    double dx2 = pt2.x - pt0.x;
    double dy2 = pt2.y - pt0.y;
    return (dx1*dx2 + dy1*dy2)/sqrt((dx1*dx1 + dy1*dy1)*(dx2*dx2 + dy2*dy2) + 1e-10);
}


+ (Mat)_grayFrom:(Mat)source {
  cout << "-> grayFrom ->";
  Mat result;
  cvtColor(source, result, COLOR_BGR2GRAY);
  return result;
}

+ (Mat)_matFrom:(UIImage *)source {
  cout << "matFrom ->";
  CGImageRef image = CGImageCreateCopy(source.CGImage);
  CGFloat cols = CGImageGetWidth(image);
  CGFloat rows = CGImageGetHeight(image);
  Mat result(rows, cols, CV_8UC4);
  CGBitmapInfo bitmapFlags = kCGImageAlphaNoneSkipLast | kCGBitmapByteOrderDefault;
  size_t bitsPerComponent = 8;
  size_t bytesPerRow = result.step[0];
  CGColorSpaceRef colorSpace = CGImageGetColorSpace(image);
  CGContextRef context = CGBitmapContextCreate(result.data, cols, rows, bitsPerComponent, bytesPerRow, colorSpace, bitmapFlags);
  CGContextDrawImage(context, CGRectMake(0.0f, 0.0f, cols, rows), image);
  CGContextRelease(context);
  return result;
}

+ (UIImage *)_imageFrom:(Mat)source {
  cout << "-> imageFrom\n";
  NSData *data = [NSData dataWithBytes:source.data length:source.elemSize() * source.total()];
  CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
  CGBitmapInfo bitmapFlags = kCGImageAlphaNone | kCGBitmapByteOrderDefault;
  size_t bitsPerComponent = 8;
  size_t bytesPerRow = source.step[0];
  CGColorSpaceRef colorSpace = (source.elemSize() == 1 ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB());
  CGImageRef image = CGImageCreate(source.cols, source.rows, bitsPerComponent, bitsPerComponent * source.elemSize(), bytesPerRow, colorSpace, bitmapFlags, provider, NULL, false, kCGRenderingIntentDefault);
  UIImage *result = [UIImage imageWithCGImage:image];
  CGImageRelease(image);
  CGDataProviderRelease(provider);
  CGColorSpaceRelease(colorSpace);
  return result;
}

@end
