project(qtemail)

cmake_minimum_required(VERSION 2.6.2)

FILE(GLOB programs src/*)
INSTALL(PROGRAMS ${programs}
  DESTINATION /opt/qtemail/bin)

FILE(GLOB qml qml/*.qml)
INSTALL(FILES ${qml}
  DESTINATION /opt/qtemail/qml)

FILE(GLOB icons icons/*.png)
INSTALL(FILES ${icons}
  DESTINATION /opt/qtemail/icons)

FILE(GLOB buttonIcons icons/buttons/*.png)
INSTALL(FILES ${buttonIcons}
  DESTINATION /opt/qtemail/icons/buttons)

INSTALL(FILES data/qtemail.desktop
  DESTINATION /usr/share/applications)
