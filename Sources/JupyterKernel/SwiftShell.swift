import Foundation
fileprivate let eventloops = Python.import("ipykernel.eventloops")
fileprivate let interactiveshell = Python.import("IPython.core.interactiveshell")
fileprivate let session = Python.import("jupyter_client.session")
fileprivate let traitlets = Python.import("traitlets")
fileprivate let zmqshell = Python.import("ipykernel.zmqshell")

fileprivate let InteractiveShellABC = interactiveshell.InteractiveShellABC
fileprivate let Session = session.Session
fileprivate let Instance = traitlets.Instance
fileprivate let ZMQInteractiveShell = zmqshell.ZMQInteractiveShell

// Caller side: use `ctypes` to convert return value, which is the address of a
// Python object, into an actual Python object. This Swift file stores a
// reference to the return value's object so that it doesn't deallocate.
@_cdecl("create_shell")
public func create_shell(
  _ username_ptr: UnsafePointer<CChar>,
  _ sessionID_ptr: UnsafePointer<CChar>, 
  _ key_ptr: UnsafePointer<CChar>
) -> Int64 {
  InteractiveShellABC.register(SwiftShell)
  
  let username = String(cString: username_ptr)
  let sessionID = String(cString: sessionID_ptr)
  let key = String(cString: key_ptr).pythonObject.encode("utf8")
  
  let socket = CapturingSocket()
  let session = Session(username: username, session: sessionID, key: key)
  let shell = SwiftShell.instance()
  shell.display_pub.session = session
  shell.display_pub.pub_socket = socket
  
  socketAndShell = [socket, shell]
  return Int64(Python.id(socketAndShell))!
}

fileprivate var socketAndShell: PythonObject!

// Simulates a ZMQ socket, saving messages instead of sending them. We use this 
// to capture display messages.
fileprivate let CapturingSocket = PythonClass(
  "CapturingSocket",
  superclasses: [],
  members: [
    "__init__": PythonInstanceMethod { (`self`: PythonObject) in
      `self`.messages = []
      return Python.None
    },
    
    "send_multipart": PythonInstanceMethod { args, kwargs in
      let `self` = args[0]
      let msg = args[1]
      `self`.messages[dynamicMember: "append"](msg)
      return Python.None
    }
  ]
).pythonObject

// An IPython shell, modified to work within Swift.
fileprivate let SwiftShell = PythonClass(
  "SwiftShell",
  superclasses: [ZMQInteractiveShell],
  members: [
    "kernel": Instance(
      "ipykernel.inprocess.ipkernel.InProcessKernel", allow_none: true),
    
    // Enable GUI integration for the kernel.
    "enable_gui": PythonInstanceMethod { args in
      let `self` = args[0]
      var gui = args[1]
      if gui == Python.None {
        gui = `self`.kernel.gui
      }
      `self`.active_eventloop = gui
      return Python.None
    },
    
    // If the normal `enable_matplotlib` is called, it might freeze while importing `matplotlib_inline.backend_inline`.

    // Enable matplotlib integration for the kernel.
    "enable_matplotlib": PythonInstanceMethod { 
      args in
      let `self` = args[0]
      var gui = args[1]
      if gui == Python.None {
        gui = args[0].kernel.gui
      }
//       print("hello world 7")
      _ = Python.import("numpy")
      return try ZMQInteractiveShell.enable_matplotlib.throwing
        .dynamicallyCall(withArguments: [`self`, gui])
      
// //       // TODO: Make these lines 80 characters
//       print("checkpoint 1")
//       PyRun_SimpleString("""
//         import sys
//         import os
//         print("checkpoint 1.3")
        
//         import matplotlib
//         print(matplotlib.__file__)
//         print("checkpoint 1.4")
//         """)
// //       let pt = Python.import("IPython.core.pylabtools")
//       print("checkpoint 1.5")
//       var backend = Python.None
//       print("checkpoint 2.1")
// //       let find_gui_and_backend = pt.find_gui_and_backend
//       (gui, backend) = find_gui_and_backend(gui, `self`.pylab_gui_select)
//       print("checkpoint 3")
      
//       if gui != "inline" {
//         print("uh oh...")
//         return Python.None
//       }
//       print("checkpoint 4")
//       activate_matplotlib(backend)
//       print("checkpoint 5")
//       try configure_inline_support(shell: `self`, backend: backend)
//       print("checkpoint 6")
      
//       `self`.enable_gui(gui)
//       print("checkpoint 7")
//       let pt = Python.import("IPython.core.pylabtools")
//       print("checkpoint 7.5")
//       `self`.magics_manager.registry["ExecutionMagics"].default_runner = pt.mpl_runner(`self`.safe_execfile)
//       print("checkpoint 8")
//       return PythonObject(tupleOf: gui, backend)
//       return Python.None
    },
    
    // Enable pylab support at runtime.
    "enable_pylab": PythonInstanceMethod { args in
      let `self` = args[0]
      var gui = args[1]
      if gui == Python.None {
        gui = `self`.kernel.gui
      }
      return try ZMQInteractiveShell.enable_pylab.throwing
        .dynamicallyCall(withArguments: `self`, gui)
    }
  ]
).pythonObject

// /// Configure an IPython shell object for matplotlib use.
// func configure_inline_support(shell: PythonObject, backend: PythonObject) throws {
//   // If using our svg payload backend, register the post-execution
//   // function that will pick up the results for display.  This can only be
//   // done with access to the real shell object.
  
//   // Move this import to the top of this file
//   let matplotlib = Python.import("matplotlib")
//   let InlineBackend = Python.import("matplotlib_inline.config").InlineBackend
  
//   let cfg = InlineBackend.instance(parent: shell)
//   cfg.shell = shell
//   if !shell.configurables.contains(cfg) {
//     shell.configurables[dynamicMember: "append"](cfg)
//   }
  
//   var new_backend_name: String
//   if backend == "module://matplotlib_inline.backend_inline" {
//     print("Control path 1")
//     shell.events.register("post_execute", flush_figures)
    
//     // Save rcParams that will be overwritten
//     shell._saved_rcParams = [:]
//     for k in cfg.rc {
//       shell._saved_rcParams[k] = matplotlib.rcParams[k]
//     }
//     // load inline_rc
//     matplotlib.rcParams.update(cfg.rc)
//     new_backend_name = "inline"
//   } else {
//     print("Control path 2")
//     do {
//       try shell.events.unregister.throwing
//         .dynamicallyCall(withArguments: ["post_execute", flush_figures])
//     } catch let error as PythonError {
//       print("An error happened")
//       switch error {
//       case .exception(let error, let traceback):
//         print("Found an exception: \(error) \(traceback)")
//         if Bool(Python.isinstance(error, Python.ValueError))! {
//           break
//         } else {
//           throw error
//         }
//       default:
//         print("Found another error type: \(error)")
//         throw error
//       }
//     }
//     if let _saved_rcParams = shell.checking._saved_rcParams {
//       if _saved_rcParams != Python.None {
//         matplotlib.rcParams.update(_saved_rcParams)
//       }
//       shell._saved_rcParams = Python.None
//     }
//     new_backend_name = "other"
    
//     // only enable the formats once -> don't change the enabled formats (which the user may
//     // has changed) when getting another "%matplotlib inline" call.
//     // See https://github.com/ipython/ipykernel/issues/29
    
//     // code disabled for now
//   }
// }

// // Try loading all imports, then seeing if the top-level code is what breaks loading the file.

// fileprivate let flush_figures = PythonFunction { _ in
//   // TODO: implement
//   return Python.None
// }.pythonObject

// fileprivate let backends: [String: String] = [
//   "tk": "TkAgg",
//   "gtk": "GTKAgg",
//   "gtk3": "GTK3Agg",
//   "gtk4": "GTK4Agg",
//   "wx": "WXAgg",
//   "qt4": "Qt4Agg",
//   "qt5": "Qt5Agg",
//   "qt6": "QtAgg",
//   "qt": "Qt5Agg",
//   "osx": "MacOSX",
//   "nbagg": "nbAgg",
//   "notebook": "nbAgg",
//   "agg": "agg",
//   "svg": "svg",
//   "pdf": "pdf",
//   "ps": "ps",
//   "inline": "module://matplotlib_inline.backend_inline",
//   "ipympl": "module://ipympl.backend_nbagg",
//   "widget": "module://ipympl.backend_nbagg",
// ]

// fileprivate func find_gui_and_backend(
//   _ input_gui: PythonObject, _ gui_select: PythonObject
// ) -> (PythonObject, PythonObject) {
//   var gui = input_gui
//   var backend = Python.None
//   if gui != Python.None && gui != "auto" {
//     print("Internal control path 1")
//     backend = PythonObject(backends[String(gui)!])
//     if gui == "agg" {
//       gui = Python.None
//     }
//   } else {
//     print("Internal control path 2")
//     fatalError("Not yet accounted for")
//   }
//   return (gui, backend)
// }

// fileprivate func activate_matplotlib(_ backend: PythonObject) {
//   print("Pre-matplotlib import")
//   let matplotlib = Python.import("matplotlib")
//   print("Post-matplotlib import")
//   matplotlib.interactive(true)
//   print("marker 0")
  
//   matplotlib.rcParams["backend"] = backend
//   print("marker 1")
  
//   let plt = Python.import("matplotlib.pyplot")
//   print("marker 2")
  
//   plt.switch_backend(backend)
//   print("marker 3")
  
//   plt.show._needmain = false
//   print("marker 4")
  
//   let flag_calls = Python.import("IPython.utils.decorators").flag_calls
//   print("marker 5")
  
//   plt.draw_if_interactive = flag_calls(plt.draw_if_interactive)
//   print("marker 6")
// }
