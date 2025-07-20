# Xcode Project Management Guidelines

## Info.plist Management

**Do not manually create Info.plist files for iOS projects.** Modern Xcode projects (using the new build system) automatically generate and manage Info.plist files based on project settings.

### Key Points:

1. **Avoid Manual Creation**: Never create `Info.plist` files manually in the project directory
2. **Use Project Settings**: Configure app permissions, bundle identifiers, and other settings through Xcode's project settings UI or build configuration files
3. **Permission Descriptions**: Add privacy usage descriptions (like `NSCameraUsageDescription`) through:
   - Xcode project settings → Info tab → Custom iOS Target Properties
   - Build settings and configuration files (.xcconfig)
   - Project.pbxproj modifications if absolutely necessary

### Why This Matters:

- Manual Info.plist files can conflict with Xcode's automatic generation
- Build errors like "Multiple commands produce Info.plist" occur when both manual and automatic files exist
- Modern Xcode projects handle Info.plist generation more efficiently

### Alternative Approaches:

- Use `.xcconfig` files for build configuration
- Modify project settings programmatically through the project.pbxproj file
- Use Xcode's GUI for adding permissions and app metadata

### Exception:

Only create manual Info.plist files when working with legacy Xcode projects that explicitly require them, or when specifically instructed by project requirements.