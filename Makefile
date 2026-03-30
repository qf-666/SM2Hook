INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64 arm64e
TARGET := iphone:clang:15.6:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = SM2Hook
SM2Hook_FILES = Tweak.x
SM2Hook_CFLAGS = -fobjc-arc
SM2Hook_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
