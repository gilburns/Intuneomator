![](https://img.shields.io/github/v/release/gilburns/Intuneomator)&nbsp;![](https://img.shields.io/github/downloads/gilburns/Intuneomator/latest/total)&nbsp;![](https://img.shields.io/badge/macOS-14.5%2B-success)&nbsp;![](https://img.shields.io/github/license/gilburns/Intuneomator)

# Intuneomator

**Swift-based automated application management for Microsoft Intune**

[![macOS](https://img.shields.io/badge/macOS-14.6+-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-5.0+-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE.md)

Intuneomator is a powerful macOS enterprise application that bridges the gap between the open-source [Installomator](https://github.com/Installomator/Installomator) project and Microsoft Intune, providing IT administrators with comprehensive automation capabilities for macOS application lifecycle management.

#### As mentioned in [MC1066336](https://mc.merill.net/message/MC1066336), starting July 31, 2025, or soon after, the following Graph APIs will require either DeviceManagementScripts.Read.All or DeviceManagementScripts.ReadWrite.All permissions to continue working:  
~/deviceManagement/deviceShellScripts  
~/deviceManagement/deviceCustomAttributeShellScripts  
~/deviceManagement/deviceManagementScripts

Since **Intuneomator** utilizes there API, you should add **DeviceManagementScripts.ReadWrite** permissions to your app registration to continue using the built in Shell Script and Custom Attribute managers.
## 🚀 Features

### **Automated Application Management**
- **900+ Application Support**: Leverages Installomator's extensive label database
- **Multi-Architecture Support**: Handles ARM64, Intel, and Universal binaries seamlessly
- **Flexible Deployment Types**: Supports DMG, PKG, and LOB (Line of Business) applications
- **Intelligent Version Detection**: Automatic monitoring and update notifications

### **Microsoft Intune Integration**
- **Complete Lifecycle Management**: Download → Package → Upload → Deploy workflow
- **Group Assignment Automation**: Azure AD group targeting with assignment filters
- **Metadata Management**: Automated app information and script generation
- **Script Automation**: Pre/post-installation script management

### **Enterprise-Grade Automation**
- **Scheduled Processing**: Launch Daemon-based automation (default: 8:30 AM/PM)
- **On-Demand Operations**: Manual trigger capability for immediate processing
- **Bulk Operations**: Process multiple applications simultaneously
- **Cache Management**: Intelligent cleanup and optimization

### **Teams Integration & Monitoring**
- **Rich Notifications**: Microsoft Teams webhook integration with adaptive cards
- **CVE Alerts**: Security vulnerability notifications with detailed information
- **Status Updates**: Real-time automation results and system health
- **Configurable Alerts**: Customizable notification types and styles

### **Security & Authentication**
- **Dual Authentication**: Support for both certificate and client secret methods
- **XPC Architecture**: Secure inter-process communication with privilege separation
- **Keychain Integration**: Secure credential storage and management
- **Certificate Management**: Built-in certificate generation and validation

## 🏗️ Architecture

Intuneomator employs a sophisticated multi-process architecture designed for security and reliability:

```
┌─────────────────────┐    XPC Communication     ┌──────────────────────┐
│   GUI Application   │◄─────────────────────────┤   Privileged Service │
│   (Intuneomator)    │                          │ (IntuneomatorService)│
│                     │    Secure IPC Bridge     │                      │
│ • User Interface    │                          │ • File Operations    │
│ • Configuration     │                          │ • Graph API Calls    │
│ • Status Display    │                          │ • Script Execution   │
└─────────────────────┘                          └──────────────────────┘
```

### **Core Components**
- **Main GUI Application**: SwiftUI-based interface for configuration and monitoring
- **XPC Service**: Privileged background service handling system operations
- **Launch Daemons**: System-level scheduled task management
- **Shared Libraries**: Common utilities and data structures

## 📋 Prerequisites

- **macOS 14.6** or later
- **Microsoft Intune** subscription with administrative access
- **Microsoft Entra ID** (Azure AD) with application registration permissions
- **Xcode 16.2+** for development

## 🛠️ Installation

### **Production Installation**
1. Download the latest release from [GitHub Releases](https://github.com/gilburns/intuneomator/releases)
2. Install the package with administrative privileges
3. Launch Intuneomator and complete the welcome wizard

### **Development Setup**
```bash
# Clone the repository
git clone https://github.com/gilburns/intuneomator.git
cd intuneomator

# Open in Xcode
open Intuneomator.xcodeproj

# Build all targets
xcodebuild -project Intuneomator.xcodeproj -scheme Intuneomator -configuration Debug
```

## ⚙️ Configuration

### **Microsoft Entra ID Setup**
1. **Create Application Registration**:
   - Navigate to Microsoft Entra admin center
   - Register new application: "Intuneomator Integration"
   - Note the **Application (client) ID** and **Directory (tenant) ID**

2. **Configure Authentication** (choose one):
   - **Certificate**: Generate and upload .p12 certificate
   - **Client Secret**: Create and securely store secret value

3. **Assign API Permissions**:
   ```
   Microsoft Graph Application Permissions:
   • DeviceManagementApps.ReadWrite.All
   • DeviceManagementConfiguration.ReadWrite.All
   • DeviceManagementManagedDevices.ReadWrite.All
   • DeviceManagementScripts.ReadWrite.All
   • Group.Read.All
   ```

4. **Grant Admin Consent** for all assigned permissions

### **Intuneomator Configuration**
1. Launch the application and complete the Welcome Wizard
2. Enter your Entra ID tenant and application details
3. Configure authentication credentials
4. Set up Teams notifications (optional)
5. Configure automation schedule and preferences

For detailed setup instructions, see [entra-app-setup.md](entra-app-setup.md).

## 🎯 Usage

### **Basic Workflow**
1. **Discover Applications**: Browse 700+ available Installomator labels
2. **Configure Deployment**: Set metadata, scripts, and group assignments
3. **Process Applications**: Manual or scheduled automation
4. **Monitor Results**: Real-time status and Teams notifications

### **Automation Scheduling**
```bash
# Default automation runs twice daily at 8:30 AM and PM
# Customize through Settings → Automation Schedule
```

### **Teams Notifications**
Configure webhook URL in Settings to receive:
- Automation completion status
- CVE vulnerability alerts
- Application update notifications
- System health monitoring

## 🗂️ File Structure

```
/Library/Application Support/Intuneomator/
├── ManagedTitles/              # Label-based app management
│   ├── chrome_12345/           # Individual app folders
│   ├── firefox_67890/
│   └── ...
├── Cache/                      # Temporary downloads
└── Installomator/              # Application logs
     ├── Custom/                # Custom Installomator Labels
     └── Labels/                # Standard Installomator Labels (Main Branch)
```

## 🔧 Advanced Features

### **Custom Labels**
- Create custom Installomator labels for proprietary applications
- Support for custom download sources and packaging logic
- Integration with existing Installomator ecosystem

### **Script Management**
- Pre-installation and post-installation script automation
- PowerShell and Shell script support
- Variable substitution and dynamic content

### **Assignment Filters**
- macOS device targeting with advanced filters
- Group-based assignment management
- Conditional deployment logic

## 🤝 Contributing

We welcome contributions! Please read our contributing guidelines and submit pull requests for any improvements.

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📖 Documentation

- **[Wiki](https://github.com/gilburns/intuneomator/wiki)**: Comprehensive documentation
- **[API Reference](docs/api/)**: XPC service interface documentation
- **[Troubleshooting](docs/troubleshooting.md)**: Common issues and solutions

## 🆘 Support

- **GitHub Issues**: [Report bugs and request features](https://github.com/gilburns/intuneomator/issues)
- **Community Forum**: [Get help from the community](https://github.com/gilburns/intuneomator/discussions)
- **Enterprise Support**: Contact for enterprise deployment assistance

## 📄 License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

## 🙏 Acknowledgments

- **[Installomator](https://github.com/Installomator/Installomator)**: The foundational open-source project
- **Microsoft Graph Team**: For comprehensive API documentation
- **macOS Admin Community**: For continuous feedback and testing

---

**Made with ❤️ for macOS Intune administrators**

*Simplifying enterprise app management, one installation at a time.*