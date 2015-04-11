project(lirrtraintime)

cmake_minimum_required(VERSION 2.6.2)

FILE(GLOB programs src/*)
INSTALL(PROGRAMS ${programs}
  DESTINATION /opt/lirrtraintime/bin)

FILE(GLOB qml qml/*.qml)
INSTALL(FILES ${qml}
  DESTINATION /opt/lirrtraintime/qml)

FILE(GLOB icons icons/*.png)
INSTALL(FILES ${icons}
  DESTINATION /opt/lirrtraintime/icons)

INSTALL(FILES data/lirrtraintime.desktop
  DESTINATION /usr/share/applications)
