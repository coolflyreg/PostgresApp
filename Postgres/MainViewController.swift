//
//  MainViewController.swift
//  Postgres
//
//  Created by Chris on 24/06/16.
//  Copyright © 2016 postgresapp. All rights reserved.
//

import Cocoa

class MainViewController: NSViewController, ServerManagerConsumer {
	
	dynamic var serverManager: ServerManager!
	
	@IBOutlet var serverArrayController: NSArrayController?
	@IBOutlet var databaseArrayController: NSArrayController?
	@IBOutlet var databaseCollectionView: NSCollectionView?
	
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.databaseCollectionView?.itemPrototype = self.storyboard?.instantiateController(withIdentifier: "DatabaseCollectionViewItem") as? NSCollectionViewItem
	}
	
	
	@IBAction func startServer(_ sender: AnyObject?) {
		guard let server = self.serverArrayController?.selectedObjects.first as? Server else { return }
		server.start { (actionStatus) in
			if case let .Failure(error) = actionStatus {
				self.errorHandler(error: error)
			}
		}
	}
	
	
	@IBAction func stopServer(_ sender: AnyObject?) {
		guard let server = self.serverArrayController?.selectedObjects.first as? Server else { return }
		server.stop { (actionStatus) in
			if case let .Failure(error) = actionStatus {
				self.view.window?.windowController?.presentError(error, modalFor: self.view.window!, delegate: self, didPresent: nil, contextInfo: nil)
			}
		}
	}
	
	
	@IBAction func openPsql(_ sender: AnyObject?) {
		guard let server = self.serverArrayController?.selectedObjects.first as? Server else { return }
		guard let database = self.databaseArrayController?.selectedObjects.first as? Database else { return }
		
		let psqlScript = String(format: "'%@/psql' -p%u -d %@", arguments: [server.binPath.replacingOccurrences(of: "'", with: "'\\''"), server.port, database.name])
		
		let wrapper = ASWrapper(fileName: "ASSubroutines")
		do {
			try wrapper.runSubroutine("openTerminalApp", parameters: [psqlScript])
		} catch {}
	}
	
	
	@IBAction func dumpDatabase(_ sender: AnyObject?) {
		guard let server = self.serverArrayController?.selectedObjects.first as? Server else { return }
		guard let database = self.databaseArrayController?.selectedObjects.first as? Database else { return }
		
		let savePanel = NSSavePanel()
		savePanel.directoryURL = URL(string: "~/Desktop")
		savePanel.nameFieldStringValue = database.name + ".pg_dump"
		savePanel.beginSheetModal(for: self.view.window!) { (result: Int) in
			if result == NSFileHandlingPanelOKButton {
				
				guard let progressViewController = self.storyboard?.instantiateController(withIdentifier: "ProgressView") as? ProgressViewController else { return }
				progressViewController.statusMessage = "Dumping Database..."
				self.presentViewControllerAsSheet(progressViewController)
				
				progressViewController.databaseTask = DatabaseTask(server)
				progressViewController.databaseTask?.dumpDatabase(name: database.name, to: savePanel.url!.path!, completionHandler: { (actionStatus) in
					progressViewController.dismiss(self)
				})
			}
		}
	}
	
	
	@IBAction func restoreDatabase(_ sender: AnyObject?) {
		guard let server = self.serverArrayController?.selectedObjects.first as? Server else { return }
		
		let openPanel = NSOpenPanel()
		openPanel.canChooseFiles = true
		openPanel.canChooseDirectories = false
		openPanel.allowsMultipleSelection = false
		openPanel.resolvesAliases = true
		openPanel.allowedFileTypes = ["pg_dump"]
		openPanel.directoryURL = URL(string: "~/Desktop")
		openPanel.beginSheetModal(for: self.view.window!) { (fileSheetResponse) in
			if fileSheetResponse == NSFileHandlingPanelOKButton {
				
				guard let databaseNameSheetController = self.storyboard?.instantiateController(withIdentifier: "DatabaseNameSheet") as? DatabaseNameSheetController else { return }
				//self.presentViewControllerAsSheet(databaseNameViewController)
				self.view.window!.beginSheet(databaseNameSheetController.window!, completionHandler: { (nameSheetResponse) in
					
					guard let progressViewController = self.storyboard?.instantiateController(withIdentifier: "ProgressView") as? ProgressViewController else { return }
					progressViewController.statusMessage = "Restoring Database..."
					self.presentViewControllerAsSheet(progressViewController)
					
					progressViewController.databaseTask = DatabaseTask(server)
					progressViewController.databaseTask?.restoreDatabase(name: "foo", from: openPanel.url!.path!, completionHandler: { (actionStatus) in
						server.loadDatabases()
						progressViewController.dismiss(self)
					})
					
				})
			}
		}
	}
	
	
	@IBAction func dropDatabase(_ sender: AnyObject?) {
		guard let server = self.serverArrayController?.selectedObjects.first as? Server else { return }
		guard let database = self.databaseArrayController?.selectedObjects.first as? Database else { return }
		
		let alert = NSAlert()
		alert.messageText = "Drop Database?"
		alert.informativeText = "This action can not be undone."
		alert.addButton(withTitle: "Drop Database")
		alert.addButton(withTitle: "Cancel")
		alert.buttons.first?.keyEquivalent = ""
		alert.beginSheetModal(for: self.view.window!) { (modalResponse) in
			if modalResponse == NSAlertFirstButtonReturn {
				
				guard let progressViewController = self.storyboard?.instantiateController(withIdentifier: "ProgressView") as? ProgressViewController else { return }
				progressViewController.statusMessage = "Dropping Database..."
				self.presentViewControllerAsSheet(progressViewController)
				
				progressViewController.databaseTask = DatabaseTask(server)
				progressViewController.databaseTask?.dropDatabase(name: database.name, completionHandler: { (actionStatus) in
					server.loadDatabases()
					progressViewController.dismiss(self)
				})
			}
		}
	}
	
	
	private func errorHandler(error: NSError) {
		guard let mainWindowController = self.view.window?.windowController else { return }
		mainWindowController.presentError(error, modalFor: mainWindowController.window!, delegate: mainWindowController, didPresent: Selector(("errorDidPresent:")), contextInfo: nil)
	}
	
	
	override func prepare(for segue: NSStoryboardSegue, sender: AnyObject?) {
		if var target = segue.destinationController as? ServerManagerConsumer {
			target.serverManager = self.serverManager
		}
	}
	
}



class MainViewBackgroundView: NSView {
	
	override var isOpaque: Bool { return true }
	override var mouseDownCanMoveWindow: Bool { return true }
	
	override func draw(_ dirtyRect: NSRect) {
		NSColor.white().setFill()
		NSRectFill(dirtyRect)
		
		let imageRect = NSRect(x: 20, y: self.bounds.maxY-20-128, width: 128, height: 128)
		if imageRect.intersects(dirtyRect) {
			NSApp.applicationIconImage.draw(in: imageRect)
		}
	}
	
}



class DatabaseNameSheetController: NSWindowController {
	
	dynamic var databaseName: String = ""
	
	
	@IBAction func ok(_ sender: AnyObject?) {
		self.window!.sheetParent!.endSheet(self.window!)
	}
	
}
