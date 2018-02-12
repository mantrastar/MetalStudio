/*****************************************************************************
  Metal Studio
  A minimal tool for building with Metal on macOS using Swift.

  by VEN (ven@mantra.io)
  version 2018.02.11

  (*) mantra
*****************************************************************************/


import Cocoa
import AppKit

import Metal
import MetalKit
import simd


/*****************************************************************************
  AppController
*****************************************************************************/

class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate
{
  var mainWindow: NSWindow?

  
  func applicationDidFinishLaunching(_ notification: Notification)
  {
    let windowMask = NSWindow.StyleMask(rawValue: (NSWindow.StyleMask.titled.rawValue | NSWindow.StyleMask.closable.rawValue))
    let window = NSWindow(contentRect: NSMakeRect(0, 0, 918, 1118),
                          styleMask: windowMask,
                          backing: NSWindow.BackingStoreType.buffered,
                          defer: true
    )
    window.orderFrontRegardless()
    window.title = "Metal Studio"
    window.setFrameOrigin(NSMakePoint(985, 18))
    window.backgroundColor = NSColor.black
    window.contentViewController = MetalViewController()
    self.mainWindow = window

    app.activate(ignoringOtherApps: true)
  }

  func applicationWillBecomeActive(_ notification: Notification)
  { }

  func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication)
  -> Bool
  {
    return true
  }

  public
  class func makeMenu()
  -> NSMenu
  {
    let mainMenu = NSMenu()
    let mainAppMenuItem = NSMenuItem(title: "\(ProcessInfo.processInfo.processName)",
                                     action: nil,
                                     keyEquivalent: ""
    )
    let mainFileMenuItem    = NSMenuItem(title: "File",
                                         action: nil,
                                         keyEquivalent: ""
    )
    mainMenu.addItem(mainAppMenuItem)
    mainMenu.addItem(mainFileMenuItem)

    let appMenu = NSMenu()
    mainAppMenuItem.submenu = appMenu

    let appServicesMenu = NSMenu()
    app.servicesMenu = appServicesMenu

    appMenu.addItem(withTitle: "About \(ProcessInfo.processInfo.processName)",
                    action: nil,
                    keyEquivalent: ""
    )
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(withTitle: "Preferences...",
                    action: nil,
                    keyEquivalent: ","
    )
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(withTitle: "Services",
                    action: nil,
                    keyEquivalent: ""
    ).submenu = appServicesMenu
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(withTitle: "Hide \(ProcessInfo.processInfo.processName)",
                    action: #selector(NSApplication.hide(_:)),
                    keyEquivalent: "h")
    appMenu.addItem({ () -> NSMenuItem in
                      let m = NSMenuItem(title: "Hide Others",
                                         action: #selector(NSApplication.hideOtherApplications(_:)),
                                         keyEquivalent: "h"
                      )
                      m.keyEquivalentModifierMask = [.command, .option]
                      return m
                    }()
    )
    appMenu.addItem(withTitle: "Show All",
                    action: #selector(NSApplication.unhideAllApplications(_:)),
                    keyEquivalent: ""
    )

    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(withTitle: "Quit \(ProcessInfo.processInfo.processName)",
                    action: #selector(NSApplication.terminate(_:)),
                    keyEquivalent: "q"
    )

    let fileMenu = NSMenu(title: "File")
    mainFileMenuItem.submenu = fileMenu
    fileMenu.addItem(withTitle: "New...",
                     action: #selector(NSDocumentController.newDocument(_:)),
                     keyEquivalent: "n"
    )

    return mainMenu
  }
}


/*****************************************************************************
  MetalViewController 
*****************************************************************************/

class MetalViewController: NSViewController
{
  var metalView: MTKView?
  var metalRenderer: MetalRenderer?
  
  override
  func loadView()
    -> ()
  {
    setupView()
    setupRenderer()
  }
  
  override
  func viewDidLoad()
    -> ()
  {
    super.viewDidLoad()
  }

  func setupView()
    -> ()
  {
    self.metalView = MTKView()
    self.view = self.metalView!
    
    self.metalView?.frame =  NSMakeRect(0, 0, 918, 1118)
    self.metalView?.layer = CAMetalLayer()
  }  

  func setupRenderer()
    -> ()
  {
    self.metalRenderer = MetalRenderer()
    if (self.metalRenderer == nil)
    {
      print("MetalRenderer failed to initialize.")
      return
    }

    self.metalView?.delegate = self.metalRenderer
    self.metalView?.preferredFramesPerSecond = 60
  }

}


/*****************************************************************************
  MetalRenderer
*****************************************************************************/

class MetalRenderer: NSObject, MTKViewDelegate
{
  var device: MTLDevice?

  var positionBuffer: MTLBuffer?
  var colorBuffer: MTLBuffer?

  var renderPipeline: MTLRenderPipelineState?
  
  var commandQueue: MTLCommandQueue?

  
  override
  init()
  {
    super.init()

    buildDevice()
    buildVertexBuffers()
    buildPipeline()
  }
  
  public
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize)
    -> ()
  {
    
  }

  public
  func draw(in view: MTKView)
    -> ()
  {
    (view.layer as! CAMetalLayer).device = self.device

    if let drawable = (view.layer as! CAMetalLayer).nextDrawable()
    {
      let frameBufferTexture = drawable.texture

      let renderPassDescriptor = MTLRenderPassDescriptor.init()
      renderPassDescriptor.colorAttachments[0].texture = frameBufferTexture
      renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0)
      renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store
      renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear

      let commandBuffer = self.commandQueue?.makeCommandBuffer()
      let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor)

      commandEncoder?.setRenderPipelineState(self.renderPipeline!)
      commandEncoder?.setVertexBuffer(self.positionBuffer!, offset: 0, index: 0)
      commandEncoder?.setVertexBuffer(self.colorBuffer!, offset: 0, index: 1)
      commandEncoder?.drawPrimitives(
        type:           MTLPrimitiveType.triangle,
        vertexStart:    0,
        vertexCount:    3,
        instanceCount:  1
      )
      commandEncoder?.endEncoding()

      commandBuffer?.present(drawable)
      commandBuffer?.commit()
    }
  }

  func buildDevice()
    -> ()
  {
    self.device = MTLCreateSystemDefaultDevice()
    if (self.device == nil)
    {
      print("Metal not supported on this machine.")
      return
    }
  }

  func buildVertexBuffers()
    -> ()
  {
    let positions: [Float] = [
       0.0,  0.5,  0.0,  1.0,
      -0.5, -0.5,  0.0,  1.0,
       0.5, -0.5,  0.0,  1.0,
    ]
    let colors: [Float] = [
       1.0,  0.0,  0.0,  1.0,
       0.0,  1.0,  0.0,  1.0,
       0.0,  0.0,  1.0,  1.0,
    ]
    self.positionBuffer = self.device?.makeBuffer(
                            bytes:    positions,
                            length:   (MemoryLayout<Float>.stride * positions.count),
                            options:  MTLResourceOptions.storageModePrivate
                          )
    self.colorBuffer = self.device?.makeBuffer(
                         bytes:    colors,
                         length:   (MemoryLayout<Float>.stride * colors.count),
                         options:  MTLResourceOptions.storageModePrivate
                       )
  }

  func buildPipeline()
    -> ()
  {
    let metalLibrary = try! self.device?.makeLibrary(filepath: "./Metal/Geometry.metallib")
    let vertexFunction = metalLibrary?.makeFunction(name: "vertex_main")
    let fragmentFunction = metalLibrary?.makeFunction(name: "fragment_main")

    let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
    renderPipelineDescriptor.vertexFunction = vertexFunction
    renderPipelineDescriptor.fragmentFunction = fragmentFunction
    renderPipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm

    self.renderPipeline = try! self.device?.makeRenderPipelineState(descriptor: renderPipelineDescriptor)

    self.commandQueue = self.device?.makeCommandQueue()
  }
  
}


/*****************************************************************************
  Main
*****************************************************************************/

let app = NSApplication.shared
app.setActivationPolicy(NSApplication.ActivationPolicy.regular)

app.mainMenu = AppController.makeMenu()
print(app.mainMenu?.items as Any)

let controller = AppController()
app.delegate = controller

app.run()
