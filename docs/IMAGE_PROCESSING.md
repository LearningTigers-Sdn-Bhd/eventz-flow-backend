# Image Processing for Resources

## Overview

The Resource model now supports automatic image processing with multiple variants for optimal performance across different use cases.

## Features

### 1. Image Variants

When a `header_img` is uploaded to a Resource, the following variants are automatically available **if vips is installed**:

- **Thumbnail**: 300x200px (WebP, 85% quality) - For card grids and list views
- **Medium**: 800x533px (WebP, 85% quality) - For previews and featured sections
- **Large**: 1600x1067px (WebP, 90% quality) - For detail page hero/header
- **Original**: Full-size uploaded image (preserves original format)

**Note**: Variants are only created if libvips is available. Without vips, all URLs point to the original image, but the API structure remains the same for frontend compatibility.

### 2. Image Validations

The system validates uploaded images:

- **Accepted formats**: JPEG, PNG, WebP
- **Maximum file size**: 10MB
- **Maximum dimensions**: 4000x4000px (if vips is available)
- Invalid uploads will return validation errors

**Important**: Validations only run on **new image uploads**, not when updating existing resources without changing the image. This prevents unnecessary validation errors during metadata updates.

### 3. Image Deletion

Resources support removing header images via the API:

- **Asynchronous deletion**: Images are purged using `purge_later` to avoid blocking the request
- **Automatic cleanup**: When an image is deleted, all variants (thumbnail, medium, large) are also removed
- **API parameter**: Send `remove_header_img: true` in the resource update payload to delete the image
- **Frontend support**: The edit form automatically detects when a user removes an image and sends the appropriate flag

## API Response Format

When fetching a Resource with an attached `header_img`, the API returns:

```json
{
  "id": 1,
  "title": "Sample Resource",
  "header_img_url": {
    "thumbnail": "http://localhost:3000/rails/active_storage/representations/.../thumbnail",
    "medium": "http://localhost:3000/rails/active_storage/representations/.../medium",
    "large": "http://localhost:3000/rails/active_storage/representations/.../large",
    "original": "http://localhost:3000/rails/active_storage/blobs/..."
  },
  ...
}
```

If no image is attached, `header_img_url` will be `null`.

## Frontend Usage

The frontend can choose the appropriate variant based on the context:

```javascript
// For list/grid views - use thumbnail
<img src={resource.header_img_url.thumbnail} alt={resource.title} />

// For featured sections - use medium
<img src={resource.header_img_url.medium} alt={resource.title} />

// For detail page header - use large
<img src={resource.header_img_url.large} alt={resource.title} />
```

## Uploading Images

### Generic Upload Endpoint (Rich Text Editor)

For rich text editor image uploads, use the generic uploads endpoint:

```bash
curl -X POST http://localhost:3000/v1/uploads \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "file=@/path/to/image.jpg" \
  -F "target=rich-editor"
```

**Features:**
- **Automatic optimization**: Images are automatically optimized for web use
- **Target-specific limits**: Different file size limits per target type
- **Content type validation**: Only allowed file types are accepted
- **Metadata tracking**: Uploads include user ID and timestamp for audit trails

**Response:**
```json
{
  "success": true,
  "message": "Success",
  "data": {
    "url": "http://localhost:3000/rails/active_storage/blobs/.../image.webp",
    "signed_id": "eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaEpJa...",
    "filename": "image.webp",
    "content_type": "image/webp",
    "byte_size": 245678
  }
}
```

#### Rich Editor Image Optimization

When uploading images with `target=rich-editor`, the system automatically:

1. **Resizes large images**: Limits dimensions to 2400x2400px (maintains aspect ratio)
2. **Converts to WebP**: All images are converted to WebP format for better compression
3. **Strips metadata**: Removes EXIF and other metadata for smaller file sizes
4. **Compresses efficiently**: Uses 85% quality for optimal size/quality balance

**File Size Limits:**
- `rich-editor`: 10MB (optimized for editor use)
- `resources`: 10MB (header images)
- `general`: 50MB (for PDFs, Excel files, etc.)

**Allowed Content Types by Target:**
- `rich-editor`: JPEG, PNG, WebP, GIF
- `resources`: JPEG, PNG, WebP, GIF
- `general`: JPEG, PNG, WebP, GIF, PDF, CSV, Excel files

**Example Optimization Results:**
```
Original: 5000x4000px JPEG, 8.5MB
↓ Automatic optimization
Optimized: 2400x1920px WebP, ~850KB
→ 90% size reduction! 🎉
```

#### Frontend Usage (Rich Text Editor)

The frontend automatically handles rich editor image uploads:

```typescript
import { uploadFile } from "@/lib/api/upload/endpoints";

// Upload image for rich text editor
const response = await uploadFile(file, "rich-editor");
const imageUrl = response.url; // Use this URL in your editor
```

**Frontend Validations:**
- Client-side file size validation (10MB limit for rich-editor)
- File type validation before upload
- Optimistic UI with blob URLs for immediate display
- Automatic cleanup of blob URLs after upload
- User-friendly error messages

### Resource Header Images

Send a multipart/form-data request with the image file:

```bash
curl -X POST http://localhost:3000/v1/resources \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "resource[title]=My Resource" \
  -F "resource[header_img]=@/path/to/image.jpg" \
  -F "resource[article]=Content here" \
  ...
```

### Via Rails Console

```ruby
resource = Resource.find(1)
resource.header_img.attach(
  io: File.open('/path/to/image.jpg'),
  filename: 'header.jpg',
  content_type: 'image/jpeg'
)
```

## Deleting Images

### Via API

To remove an existing header image from a resource, send a PATCH request with `remove_header_img: true`:

```bash
curl -X PATCH http://localhost:3000/v1/resources/1 \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "resource": {
      "remove_header_img": true
    }
  }'
```

Or via multipart/form-data:

```bash
curl -X PATCH http://localhost:3000/v1/resources/1 \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -F "resource[remove_header_img]=true"
```

**Note**: The image deletion is processed asynchronously using `purge_later` to avoid blocking the request. The attachment will be removed from ActiveStorage and all variants will be deleted.

### Via Rails Console

```ruby
resource = Resource.find(1)
resource.header_img.purge  # Synchronous deletion
# or
resource.header_img.purge_later  # Asynchronous deletion (recommended for production)
```

### Frontend Implementation

When using the edit form in the frontend:
- If a resource has an existing image and the user clicks "Remove", the form sends `remove_header_img: true`
- If a user uploads a new image, it replaces the old one automatically
- If a resource never had an image, no deletion flag is sent

## Image Processing Library

The system uses the `image_processing` gem with **libvips** as the backend for fast, memory-efficient image transformations.

### System Requirements

Ensure libvips is installed on your system.

**For detailed cross-platform setup instructions, see:** [CROSS_PLATFORM_SETUP.md](./CROSS_PLATFORM_SETUP.md)

**Quick install:**
```bash
# Homebrew/Linuxbrew (macOS/Linux) - Recommended
brew install vips

# Fedora/RHEL
sudo dnf install vips vips-devel

# Ubuntu/Debian
sudo apt-get install libvips libvips-dev

# Arch
sudo pacman -S libvips
```

### Environment Setup

The app includes automatic detection and configuration for Homebrew/Linuxbrew installations. However, for best results:

1. **Using direnv (Recommended):**
   ```bash
   cd eventz-flow-backend
   direnv allow  # Loads .envrc automatically
   ```

2. **Manual setup:**
   ```bash
   source .envrc  # Sets LD_LIBRARY_PATH for Homebrew libs
   ```

The `.envrc` file automatically configures `LD_LIBRARY_PATH` and `PKG_CONFIG_PATH` for Homebrew installations.

### Graceful Degradation

**The application works even without libvips installed!**

- ✅ **Without vips**: App functions normally, image uploads work, original images are stored and served
- ✅ **With vips**: Full functionality with optimized WebP variants (thumbnail, medium, large)
- ✅ **Automatic detection**: The system automatically detects vips availability and adapts accordingly

When vips is not available:
- Image variants are not generated (variants object is not defined)
- All image URLs point to the original image
- No errors or crashes - the app continues to function normally

### Validation Behavior

- **New uploads**: Always validated (format, size, dimensions if vips available)
- **Updates without image changes**: Existing images are not re-validated
- **Updates with new images**: Only the new image is validated

This prevents unnecessary validation errors when updating resource metadata without changing images.

## Error Handling

If variant generation fails (e.g., corrupted image, vips not available), the API will gracefully fall back to returning the original URL for all variant sizes:

```json
{
  "header_img_url": {
    "thumbnail": "http://localhost:3000/rails/active_storage/blobs/.../original.jpg",
    "medium": "http://localhost:3000/rails/active_storage/blobs/.../original.jpg",
    "large": "http://localhost:3000/rails/active_storage/blobs/.../original.jpg",
    "original": "http://localhost:3000/rails/active_storage/blobs/.../original.jpg"
  }
}
```

If the blob doesn't exist (e.g., deleted or orphaned), `header_img_url` will be `null`.

## Generic Uploads API

### POST `/v1/uploads`

Generic file upload endpoint for various use cases, with automatic optimization for images.

#### Request

**Content-Type:** `multipart/form-data`

**Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file` | File | Yes | The file to upload |
| `target` | String | No | Target identifier (`rich-editor`, `resources`, `general`) |

**Headers:**
```
Authorization: Bearer YOUR_JWT_TOKEN
Content-Type: multipart/form-data
```

#### Response

**Success (200 OK):**
```json
{
  "success": true,
  "message": "Success",
  "data": {
    "url": "http://localhost:3000/rails/active_storage/blobs/.../image.webp",
    "signed_id": "eyJfcmFpbHMiOnsibWVzc2FnZSI6IkJBaEpJa...",
    "filename": "image.webp",
    "content_type": "image/webp",
    "byte_size": 245678
  }
}
```

#### Target Types

1. **`rich-editor`** - Rich text editor images
   - Max size: 10MB
   - Allowed: JPEG, PNG, WebP, GIF
   - **Automatic optimization**: Resize to max 2400x2400px, convert to WebP, strip metadata, compress to 85% quality

2. **`resources`** - Resource header images
   - Max size: 10MB
   - Allowed: JPEG, PNG, WebP, GIF

3. **`general`** - General file uploads
   - Max size: 50MB
   - Allowed: JPEG, PNG, WebP, GIF, PDF, CSV, Excel files

#### Rich Editor Image Optimization

When uploading images with `target=rich-editor`, the system automatically:

1. **Validates file**: Checks size (10MB) and type (images only)
2. **Resizes large images**: Limits dimensions to 2400x2400px (maintains aspect ratio)
3. **Converts to WebP**: All images are converted to WebP format for better compression
4. **Strips metadata**: Removes EXIF and other metadata for smaller file sizes
5. **Compresses efficiently**: Uses 85% quality for optimal size/quality balance

**Example Optimization Results:**
```
Original: 5000x4000px JPEG, 8.5MB
↓ Automatic optimization
Optimized: 2400x1920px WebP, ~850KB
→ 90% size reduction! 🎉
```

#### Error Responses

**422 Unprocessable Entity** - Validation errors:
```json
{
  "success": false,
  "message": "File size exceeds maximum allowed size of 10MB",
  "errors": []
}
```

**422 Unprocessable Entity** - Invalid file type:
```json
{
  "success": false,
  "message": "File type 'application/zip' is not allowed. Allowed types: image/jpeg, image/png, image/webp, image/gif",
  "errors": []
}
```

#### Metadata

All uploads include metadata for tracking:
- `target`: Upload target identifier
- `uploaded_by`: User ID who uploaded the file
- `uploaded_at`: ISO 8601 timestamp

#### Frontend Integration

The frontend automatically handles validation and optimization:

```typescript
import { uploadFile } from "@/lib/api/upload/endpoints";

// Upload image for rich text editor
const response = await uploadFile(file, "rich-editor");
const imageUrl = response.url; // Use this URL in your editor
```

**Frontend Features:**
- Client-side file size validation (10MB limit for rich-editor)
- File type validation before upload
- Optimistic UI with blob URLs for immediate display
- Automatic cleanup of blob URLs after upload
- User-friendly error messages

## Performance Notes

- **Variants are generated on-demand** - The first request for a variant will generate it, subsequent requests serve the cached version
- **Storage**: Variants are stored separately from the original image
- **Bandwidth**: Using appropriate variants can reduce bandwidth by 70-90% compared to always serving full-size images

## Testing

Run the image processing tests:

```bash
bundle exec rspec spec/models/resource_spec.rb -e "image processing"
```

## Troubleshooting

### Vips Library Not Found

If you see errors about vips not being found:

1. **Verify installation:**
   ```bash
   vips --version  # Should show version number
   ```

2. **Check library path:**
   ```bash
   ls -la /home/linuxbrew/.linuxbrew/lib/libvips.so.42  # Linuxbrew
   ls -la /opt/homebrew/lib/libvips.dylib  # macOS Homebrew
   ```

3. **Ensure environment is loaded:**
   ```bash
   # Using direnv (recommended)
   direnv allow

   # Or manually source .envrc
   source .envrc

   # Verify LD_LIBRARY_PATH is set
   echo $LD_LIBRARY_PATH
   ```

4. **Restart Rails server** after setting up the environment

5. **Check Rails logs** for vips initialization messages:
   - Success: `✅ Vips library is available for image processing (version: X.X.X)`
   - Warning: `⚠️ Vips library not available: ...`

### App Works Without Vips

The application is designed to work without vips. If vips isn't installed:
- Images upload and store correctly
- Original images are served
- No variants are generated (all URLs point to original)
- No errors or crashes

To enable full functionality with optimized WebP variants, install libvips as shown above.

## Future Enhancements

Potential improvements:

- ✅ ~~Add WebP conversion for all variants~~ (Already implemented when vips is available)
- ✅ ~~Add image deletion API endpoint~~ (Already implemented via `remove_header_img` parameter)
- ✅ ~~Add generic uploads endpoint with automatic optimization~~ (Already implemented)
- ✅ ~~Add rich editor image optimization~~ (Already implemented with automatic resizing and WebP conversion)
- Implement eager loading of variants for frequently accessed resources
- Add blur placeholder generation for progressive image loading
- Support for custom crop positions (center, top, bottom)
- Automatic cleanup of orphaned image attachments
