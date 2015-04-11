#!/usr/bin/python
#qtbtn.py
#Copyright 2012,2015 Elliot Wolk
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

from PySide.QtGui import *
from PySide.QtCore import *
from PySide.QtDeclarative import *

import os
import os.path
import re
import signal
import sys
import subprocess

LIRRTRAINTIME_BIN = "/opt/lirrtraintime/bin/lirrtraintime.pl"
QML_DIR = "/opt/lirrtraintime/qml"

PLATFORM_OTHER = 0
PLATFORM_HARMATTAN = 1

signal.signal(signal.SIGINT, signal.SIG_DFL)

PAGE_INITIAL_SIZE = 200
PAGE_MORE_SIZE = 200

usage = """Usage:
  %(exec)s
""" % {"exec": sys.argv[0]}

def die(msg):
  print >> sys.stderr, msg
  sys.exit(1)

def main():
  args = sys.argv
  args.pop(0)

  if len(args) > 0:
    die(usage)

  issue = open('/etc/issue').read().strip().lower()
  platform = None
  if "harmattan" in issue:
    platform = PLATFORM_HARMATTAN
  else:
    platform = PLATFORM_OTHER

  if platform == PLATFORM_HARMATTAN:
    qmlFile = QML_DIR + "/harmattan.qml"
  else:
    qmlFile = QML_DIR + "/desktop.qml"

  stationManager = StationManager()
  stationModel = StationModel()
  controller = Controller(stationManager, stationModel)

  app = QApplication([])
  widget = MainWindow(qmlFile, controller, stationModel)
  if platform == PLATFORM_HARMATTAN:
    widget.window().showFullScreen()
  else:
    widget.window().show()

  app.exec_()

class StationManager(QObject):
  def __init__(self):
    self.stations = [ 'NYK', 'Penn Station'
                    , 'CPG', 'Copiague'
                    , 'FMD', 'Farmingdale'
                    , 'BTA', 'Babylon'
                    , 'RVC', 'Rockville Centre'
                    , 'ABT', 'Albertson'
                    , 'ADL', 'Auburndale'
                    , 'AGT', 'Amagansett'
                    , 'ATL', 'Flatbush Avenue'
                    , 'AVL', 'Amityville'
                    , 'BDY', 'Broadway'
                    , 'BHN', 'Bridgehampton'
                    , 'BK', 'Stony Brook'
                    , 'BMR', 'Bellmore'
                    , 'BPG', 'Bethpage'
                    , 'BPT', 'Bellport'
                    , 'BRS', 'Bellerose'
                    , 'BRT', 'Belmont Race Track'
                    , 'BSD', 'Bayside'
                    , 'BSR', 'Bay Shore'
                    , 'BWD', 'Brentwood'
                    , 'BWN', 'Baldwin'
                    , 'CAV', 'Centre Avenue'
                    , 'CHT', 'Cedarhurst'
                    , 'CI', 'Central Islip'
                    , 'CLP', 'Country Life Press'
                    , 'CPL', 'Carle Place'
                    , 'CSH', 'Cold Spring Harbor'
                    , 'DGL', 'Douglaston'
                    , 'DPK', 'Deer Park'
                    , 'EHN', 'East Hampton'
                    , 'ENY', 'East New York'
                    , 'ERY', 'East Rockaway'
                    , 'EWN', 'East Williston'
                    , 'FHL', 'Forest Hills'
                    , 'FLS', 'Flushing'
                    , 'FPK', 'Floral Park'
                    , 'FPT', 'Freeport'
                    , 'FRY', 'Far Rockaway'
                    , 'GBN', 'Gibson'
                    , 'GCV', 'Glen Cove'
                    , 'GCY', 'Garden City'
                    , 'GHD', 'Glen Head'
                    , 'GNK', 'Great Neck'
                    , 'GPT', 'Greenport'
                    , 'GRV', 'Great River'
                    , 'GST', 'Glen Street'
                    , 'GVL', 'Greenvale'
                    , 'GWN', 'Greenlawn'
                    , 'HBY', 'Hampton Bays'
                    , 'HEM', 'Hempstead'
                    , 'HGN', 'Hempstead Gardens'
                    , 'HOL', 'Hollis'
                    , 'HPA', 'Hunterspoint Ave.'
                    , 'HUN', 'Huntington'
                    , 'HVL', 'Hicksville'
                    , 'HWT', 'Hewlett'
                    , 'IPK', 'Island Park'
                    , 'ISP', 'Islip'
                    , 'IWD', 'Inwood'
                    , 'JAM', 'Jamaica'
                    , 'KGN', 'Kew Gardens'
                    , 'KPK', 'Kings Park'
                    , 'LBH', 'Long Beach'
                    , 'LCE', 'Lawrence'
                    , 'LHT', 'Lindenhurst'
                    , 'LIC', 'Long Island City'
                    , 'LMR', 'Locust Manor'
                    , 'LNK', 'Little Neck'
                    , 'LTN', 'Laurelton'
                    , 'LVL', 'Locust Valley'
                    , 'LVW', 'Lakeview'
                    , 'LYN', 'Lynbrook'
                    , 'MAK', 'Mattituck'
                    , 'MAV', 'Merillon Avenue'
                    , 'MFD', 'Medford'
                    , 'MHL', 'Murray Hill'
                    , 'MHT', 'Manhasset'
                    , 'MIN', 'Mineola'
                    , 'MPK', 'Massapequa Park'
                    , 'MQA', 'Massapequa'
                    , 'MRK', 'Merrick'
                    , 'MSY', 'Mastic Shirley'
                    , 'MTK', 'Montauk'
                    , 'MVN', 'Malverne'
                    , 'NAV', 'Nostrand Ave.'
                    , 'NBD', 'Nassau Blvd'
                    , 'NHP', 'New Hyde Park'
                    , 'NPT', 'Northport'
                    , 'OBY', 'Oyster Bay'
                    , 'ODE', 'Oceanside'
                    , 'ODL', 'Oakdale'
                    , 'PD', 'Patchogue'
                    , 'PDM', 'Plandome'
                    , 'PJN', 'Port Jefferson'
                    , 'PLN', 'Pinelawn'
                    , 'PWS', 'Port Washington'
                    , 'QVG', 'Queens Village'
                    , 'RHD', 'Riverhead'
                    , 'RON', 'Ronkonkoma'
                    , 'ROS', 'Rosedale'
                    , 'RSN', 'Roslyn'
                    , 'SAB', 'St. Albans'
                    , 'SCF', 'Sea Cliff'
                    , 'SFD', 'Seaford'
                    , 'SHD', 'Southold'
                    , 'SHN', 'Southampton'
                    , 'SJM', 'St. James'
                    , 'SMR', 'Stewart Manor'
                    , 'SPK', 'Speonk'
                    , 'SSM', 'Mets-Willets Point'
                    , 'STN', 'Smithtown'
                    , 'SVL', 'Sayville'
                    , 'SYT', 'Syosset'
                    , 'VSM', 'Valley Stream'
                    , 'WBY', 'Westbury'
                    , 'WDD', 'Woodside'
                    , 'WGH', 'Wantagh'
                    , 'WHD', 'West Hempstead'
                    , 'WHN', 'Westhampton'
                    , 'WMR', 'Woodmere'
                    , 'WWD', 'Westwood'
                    , 'WYD', 'Wyandanch'
                    , 'YPK', 'Yaphank'
                    ]
    self.stationList = []
    self.stationOrder = []
    self.stationNamesById = {}
    i=0
    while i < len(self.stations):
      stationId = self.stations[i]
      name = self.stations[i+1]
      self.stationOrder.append(stationId)
      self.stationNamesById[stationId] = name
      self.stationList.append(Station(stationId, name))
      i+=2
  def getStations(self):
    return self.stationList

class Controller(QObject):
  def __init__(self, stationManager, stationModel):
    QObject.__init__(self)
    self.stationManager = stationManager
    self.stationModel = stationModel
    self.setupStations()
    self.curTo = None
    self.curFrom = None
    self.curDate = None
    self.curTime = None

  @Slot('QVariantList')
  def runCommand(self, cmdArr):
    subprocess.Popen(cmdArr)
  @Slot(str)
  def shellCommand(self, cmdStr):
    subprocess.Popen(['sh', '-c', cmdStr])

  @Slot(QObject, str, result=QObject)
  def findChild(self, obj, name):
    return obj.findChild(QObject, name)

  @Slot()
  def setupStations(self):
    self.stationModel.setItems(self.stationManager.getStations())

  @Slot(str, str)
  def stationSelected(self, fieldName, stationId):
    if fieldName == "from":
      self.curFrom = stationId
    elif fieldName == "to":
      self.curTo = stationId

  @Slot(str)
  def timeSelected(self, time):
    self.curTime = time
    if self.curTime == "none":
      self.curTime = None

  @Slot(str)
  def dateSelected(self, date):
    self.curDate = date
    if self.curDate == "none":
      self.curDate = None

  @Slot()
  def search(self):
    cmd = ["lirr_train_time", "-b", self.curFrom, self.curTo]
    time = self.curTime
    date = self.curDate
    if time != None and date == None:
      date = "next"
    if date != None:
      cmd.append(date)
      cmd.append(time)
    self.runCommand(cmd)

  @Slot(result=str)
  def formatLabelText(self):
    return (""
      + "  From: " + str(self.curFrom)
      + "  To: " + str(self.curTo)
      + "\n"
      + "  Date: " + str(self.curDate)
      + "  Time: " + str(self.curTime)
    )

class BaseListModel(QAbstractListModel):
  def __init__(self):
    QAbstractListModel.__init__(self)
    self.items = []
  def getItems(self):
    return self.items
  def setItems(self, items):
    self.clear()
    if len(items) > 0:
      self.beginInsertRows(QModelIndex(), 0, 0)
      self.items = items
      self.endInsertRows()
    else:
      self.items = []
  def appendItems(self, items):
    self.beginInsertRows(QModelIndex(), len(self.items), len(self.items))
    self.items.extend(items)
    self.endInsertRows()
  def rowCount(self, parent=QModelIndex()):
    return len(self.items)
  def data(self, index, role):
    if role == Qt.DisplayRole:
      return self.items[index.row()]
  def clear(self):
    self.removeRows(0, len(self.items))
  def removeRows(self, firstRow, rowCount, parent = QModelIndex()):
    self.beginRemoveRows(parent, firstRow, firstRow+rowCount-1)
    while rowCount > 0:
      del self.items[firstRow]
      rowCount -= 1
    self.endRemoveRows()

class StationModel(BaseListModel):
  COLUMNS = ('station',)
  def __init__(self):
    BaseListModel.__init__(self)
    self.setRoleNames(dict(enumerate(StationModel.COLUMNS)))

class Station(QObject):
  def __init__(self, stationId_, name_):
    QObject.__init__(self)
    self.stationId_ = stationId_
    self.name_ = name_
  def StationId(self):
    return self.stationId_
  def Name(self):
    return self.name_
  changed = Signal()
  StationId = Property(unicode, StationId, notify=changed)
  Name = Property(unicode, Name, notify=changed)

class MainWindow(QDeclarativeView):
  def __init__(self, qmlFile, controller, stationModel):
    super(MainWindow, self).__init__(None)
    context = self.rootContext()
    context.setContextProperty('stationModel', stationModel)
    context.setContextProperty('controller', controller)

    self.setResizeMode(QDeclarativeView.SizeRootObjectToView)
    self.setSource(qmlFile)

if __name__ == "__main__":
  sys.exit(main())
