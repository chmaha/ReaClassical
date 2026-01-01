# Generated for ReaImGui v0.10.0.2

from reaper_python import *

def ArrowButton(ctx, str_id, dir):
  if not hasattr(ArrowButton, 'func'):
    proc = rpr_getfp('ImGui_ArrowButton')
    ArrowButton.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_int)(proc)
  args = (c_void_p(ctx), rpr_packsc(str_id), c_int(dir))
  rval = ArrowButton.func(args[0], args[1], args[2])
  return rval

def Button(ctx, label, size_wInOptional = None, size_hInOptional = None):
  if not hasattr(Button, 'func'):
    proc = rpr_getfp('ImGui_Button')
    Button.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_double(size_wInOptional) if size_wInOptional != None else None, c_double(size_hInOptional) if size_hInOptional != None else None)
  rval = Button.func(args[0], args[1], byref(args[2]) if args[2] != None else None, byref(args[3]) if args[3] != None else None)
  return rval

def Checkbox(ctx, label, vInOut):
  if not hasattr(Checkbox, 'func'):
    proc = rpr_getfp('ImGui_Checkbox')
    Checkbox.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_bool(vInOut))
  rval = Checkbox.func(args[0], args[1], byref(args[2]))
  return rval, int(args[2].value)

def CheckboxFlags(ctx, label, flagsInOut, flags_value):
  if not hasattr(CheckboxFlags, 'func'):
    proc = rpr_getfp('ImGui_CheckboxFlags')
    CheckboxFlags.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_int)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(flagsInOut), c_int(flags_value))
  rval = CheckboxFlags.func(args[0], args[1], byref(args[2]), args[3])
  return rval, int(args[2].value)

def InvisibleButton(ctx, str_id, size_w, size_h, flagsInOptional = None):
  if not hasattr(InvisibleButton, 'func'):
    proc = rpr_getfp('ImGui_InvisibleButton')
    InvisibleButton.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_double, c_double, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(str_id), c_double(size_w), c_double(size_h), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = InvisibleButton.func(args[0], args[1], args[2], args[3], byref(args[4]) if args[4] != None else None)
  return rval

def RadioButton(ctx, label, active):
  if not hasattr(RadioButton, 'func'):
    proc = rpr_getfp('ImGui_RadioButton')
    RadioButton.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_bool)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_bool(active))
  rval = RadioButton.func(args[0], args[1], args[2])
  return rval

def RadioButtonEx(ctx, label, vInOut, v_button):
  if not hasattr(RadioButtonEx, 'func'):
    proc = rpr_getfp('ImGui_RadioButtonEx')
    RadioButtonEx.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_int)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(vInOut), c_int(v_button))
  rval = RadioButtonEx.func(args[0], args[1], byref(args[2]), args[3])
  return rval, int(args[2].value)

def SmallButton(ctx, label):
  if not hasattr(SmallButton, 'func'):
    proc = rpr_getfp('ImGui_SmallButton')
    SmallButton.func = CFUNCTYPE(c_bool, c_void_p, c_char_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label))
  rval = SmallButton.func(args[0], args[1])
  return rval

def Dir_Down():
  if not hasattr(Dir_Down, 'func'):
    proc = rpr_getfp('ImGui_Dir_Down')
    Dir_Down.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Dir_Down, 'cache'):
    Dir_Down.cache = Dir_Down.func()
  return Dir_Down.cache

def Dir_Left():
  if not hasattr(Dir_Left, 'func'):
    proc = rpr_getfp('ImGui_Dir_Left')
    Dir_Left.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Dir_Left, 'cache'):
    Dir_Left.cache = Dir_Left.func()
  return Dir_Left.cache

def Dir_None():
  if not hasattr(Dir_None, 'func'):
    proc = rpr_getfp('ImGui_Dir_None')
    Dir_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Dir_None, 'cache'):
    Dir_None.cache = Dir_None.func()
  return Dir_None.cache

def Dir_Right():
  if not hasattr(Dir_Right, 'func'):
    proc = rpr_getfp('ImGui_Dir_Right')
    Dir_Right.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Dir_Right, 'cache'):
    Dir_Right.cache = Dir_Right.func()
  return Dir_Right.cache

def Dir_Up():
  if not hasattr(Dir_Up, 'func'):
    proc = rpr_getfp('ImGui_Dir_Up')
    Dir_Up.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Dir_Up, 'cache'):
    Dir_Up.cache = Dir_Up.func()
  return Dir_Up.cache

def ButtonFlags_EnableNav():
  if not hasattr(ButtonFlags_EnableNav, 'func'):
    proc = rpr_getfp('ImGui_ButtonFlags_EnableNav')
    ButtonFlags_EnableNav.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ButtonFlags_EnableNav, 'cache'):
    ButtonFlags_EnableNav.cache = ButtonFlags_EnableNav.func()
  return ButtonFlags_EnableNav.cache

def ButtonFlags_MouseButtonLeft():
  if not hasattr(ButtonFlags_MouseButtonLeft, 'func'):
    proc = rpr_getfp('ImGui_ButtonFlags_MouseButtonLeft')
    ButtonFlags_MouseButtonLeft.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ButtonFlags_MouseButtonLeft, 'cache'):
    ButtonFlags_MouseButtonLeft.cache = ButtonFlags_MouseButtonLeft.func()
  return ButtonFlags_MouseButtonLeft.cache

def ButtonFlags_MouseButtonMiddle():
  if not hasattr(ButtonFlags_MouseButtonMiddle, 'func'):
    proc = rpr_getfp('ImGui_ButtonFlags_MouseButtonMiddle')
    ButtonFlags_MouseButtonMiddle.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ButtonFlags_MouseButtonMiddle, 'cache'):
    ButtonFlags_MouseButtonMiddle.cache = ButtonFlags_MouseButtonMiddle.func()
  return ButtonFlags_MouseButtonMiddle.cache

def ButtonFlags_MouseButtonRight():
  if not hasattr(ButtonFlags_MouseButtonRight, 'func'):
    proc = rpr_getfp('ImGui_ButtonFlags_MouseButtonRight')
    ButtonFlags_MouseButtonRight.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ButtonFlags_MouseButtonRight, 'cache'):
    ButtonFlags_MouseButtonRight.cache = ButtonFlags_MouseButtonRight.func()
  return ButtonFlags_MouseButtonRight.cache

def ButtonFlags_None():
  if not hasattr(ButtonFlags_None, 'func'):
    proc = rpr_getfp('ImGui_ButtonFlags_None')
    ButtonFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ButtonFlags_None, 'cache'):
    ButtonFlags_None.cache = ButtonFlags_None.func()
  return ButtonFlags_None.cache

def ColorButton(ctx, desc_id, col_rgba, flagsInOptional = None, size_wInOptional = None, size_hInOptional = None):
  if not hasattr(ColorButton, 'func'):
    proc = rpr_getfp('ImGui_ColorButton')
    ColorButton.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_int, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(desc_id), c_int(col_rgba), c_int(flagsInOptional) if flagsInOptional != None else None, c_double(size_wInOptional) if size_wInOptional != None else None, c_double(size_hInOptional) if size_hInOptional != None else None)
  rval = ColorButton.func(args[0], args[1], args[2], byref(args[3]) if args[3] != None else None, byref(args[4]) if args[4] != None else None, byref(args[5]) if args[5] != None else None)
  return rval

def ColorEdit3(ctx, label, col_rgbInOut, flagsInOptional = None):
  if not hasattr(ColorEdit3, 'func'):
    proc = rpr_getfp('ImGui_ColorEdit3')
    ColorEdit3.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(col_rgbInOut), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = ColorEdit3.func(args[0], args[1], byref(args[2]), byref(args[3]) if args[3] != None else None)
  return rval, int(args[2].value)

def ColorEdit4(ctx, label, col_rgbaInOut, flagsInOptional = None):
  if not hasattr(ColorEdit4, 'func'):
    proc = rpr_getfp('ImGui_ColorEdit4')
    ColorEdit4.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(col_rgbaInOut), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = ColorEdit4.func(args[0], args[1], byref(args[2]), byref(args[3]) if args[3] != None else None)
  return rval, int(args[2].value)

def ColorPicker3(ctx, label, col_rgbInOut, flagsInOptional = None):
  if not hasattr(ColorPicker3, 'func'):
    proc = rpr_getfp('ImGui_ColorPicker3')
    ColorPicker3.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(col_rgbInOut), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = ColorPicker3.func(args[0], args[1], byref(args[2]), byref(args[3]) if args[3] != None else None)
  return rval, int(args[2].value)

def ColorPicker4(ctx, label, col_rgbaInOut, flagsInOptional = None, ref_colInOptional = None):
  if not hasattr(ColorPicker4, 'func'):
    proc = rpr_getfp('ImGui_ColorPicker4')
    ColorPicker4.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(col_rgbaInOut), c_int(flagsInOptional) if flagsInOptional != None else None, c_int(ref_colInOptional) if ref_colInOptional != None else None)
  rval = ColorPicker4.func(args[0], args[1], byref(args[2]), byref(args[3]) if args[3] != None else None, byref(args[4]) if args[4] != None else None)
  return rval, int(args[2].value)

def SetColorEditOptions(ctx, flags):
  if not hasattr(SetColorEditOptions, 'func'):
    proc = rpr_getfp('ImGui_SetColorEditOptions')
    SetColorEditOptions.func = CFUNCTYPE(None, c_void_p, c_int)(proc)
  args = (c_void_p(ctx), c_int(flags))
  SetColorEditOptions.func(args[0], args[1])

def ColorEditFlags_NoAlpha():
  if not hasattr(ColorEditFlags_NoAlpha, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_NoAlpha')
    ColorEditFlags_NoAlpha.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_NoAlpha, 'cache'):
    ColorEditFlags_NoAlpha.cache = ColorEditFlags_NoAlpha.func()
  return ColorEditFlags_NoAlpha.cache

def ColorEditFlags_NoBorder():
  if not hasattr(ColorEditFlags_NoBorder, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_NoBorder')
    ColorEditFlags_NoBorder.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_NoBorder, 'cache'):
    ColorEditFlags_NoBorder.cache = ColorEditFlags_NoBorder.func()
  return ColorEditFlags_NoBorder.cache

def ColorEditFlags_NoDragDrop():
  if not hasattr(ColorEditFlags_NoDragDrop, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_NoDragDrop')
    ColorEditFlags_NoDragDrop.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_NoDragDrop, 'cache'):
    ColorEditFlags_NoDragDrop.cache = ColorEditFlags_NoDragDrop.func()
  return ColorEditFlags_NoDragDrop.cache

def ColorEditFlags_NoInputs():
  if not hasattr(ColorEditFlags_NoInputs, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_NoInputs')
    ColorEditFlags_NoInputs.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_NoInputs, 'cache'):
    ColorEditFlags_NoInputs.cache = ColorEditFlags_NoInputs.func()
  return ColorEditFlags_NoInputs.cache

def ColorEditFlags_NoLabel():
  if not hasattr(ColorEditFlags_NoLabel, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_NoLabel')
    ColorEditFlags_NoLabel.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_NoLabel, 'cache'):
    ColorEditFlags_NoLabel.cache = ColorEditFlags_NoLabel.func()
  return ColorEditFlags_NoLabel.cache

def ColorEditFlags_NoOptions():
  if not hasattr(ColorEditFlags_NoOptions, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_NoOptions')
    ColorEditFlags_NoOptions.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_NoOptions, 'cache'):
    ColorEditFlags_NoOptions.cache = ColorEditFlags_NoOptions.func()
  return ColorEditFlags_NoOptions.cache

def ColorEditFlags_NoPicker():
  if not hasattr(ColorEditFlags_NoPicker, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_NoPicker')
    ColorEditFlags_NoPicker.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_NoPicker, 'cache'):
    ColorEditFlags_NoPicker.cache = ColorEditFlags_NoPicker.func()
  return ColorEditFlags_NoPicker.cache

def ColorEditFlags_NoSidePreview():
  if not hasattr(ColorEditFlags_NoSidePreview, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_NoSidePreview')
    ColorEditFlags_NoSidePreview.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_NoSidePreview, 'cache'):
    ColorEditFlags_NoSidePreview.cache = ColorEditFlags_NoSidePreview.func()
  return ColorEditFlags_NoSidePreview.cache

def ColorEditFlags_NoSmallPreview():
  if not hasattr(ColorEditFlags_NoSmallPreview, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_NoSmallPreview')
    ColorEditFlags_NoSmallPreview.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_NoSmallPreview, 'cache'):
    ColorEditFlags_NoSmallPreview.cache = ColorEditFlags_NoSmallPreview.func()
  return ColorEditFlags_NoSmallPreview.cache

def ColorEditFlags_NoTooltip():
  if not hasattr(ColorEditFlags_NoTooltip, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_NoTooltip')
    ColorEditFlags_NoTooltip.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_NoTooltip, 'cache'):
    ColorEditFlags_NoTooltip.cache = ColorEditFlags_NoTooltip.func()
  return ColorEditFlags_NoTooltip.cache

def ColorEditFlags_None():
  if not hasattr(ColorEditFlags_None, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_None')
    ColorEditFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_None, 'cache'):
    ColorEditFlags_None.cache = ColorEditFlags_None.func()
  return ColorEditFlags_None.cache

def ColorEditFlags_AlphaNoBg():
  if not hasattr(ColorEditFlags_AlphaNoBg, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_AlphaNoBg')
    ColorEditFlags_AlphaNoBg.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_AlphaNoBg, 'cache'):
    ColorEditFlags_AlphaNoBg.cache = ColorEditFlags_AlphaNoBg.func()
  return ColorEditFlags_AlphaNoBg.cache

def ColorEditFlags_AlphaOpaque():
  if not hasattr(ColorEditFlags_AlphaOpaque, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_AlphaOpaque')
    ColorEditFlags_AlphaOpaque.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_AlphaOpaque, 'cache'):
    ColorEditFlags_AlphaOpaque.cache = ColorEditFlags_AlphaOpaque.func()
  return ColorEditFlags_AlphaOpaque.cache

def ColorEditFlags_AlphaPreviewHalf():
  if not hasattr(ColorEditFlags_AlphaPreviewHalf, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_AlphaPreviewHalf')
    ColorEditFlags_AlphaPreviewHalf.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_AlphaPreviewHalf, 'cache'):
    ColorEditFlags_AlphaPreviewHalf.cache = ColorEditFlags_AlphaPreviewHalf.func()
  return ColorEditFlags_AlphaPreviewHalf.cache

def ColorEditFlags_AlphaBar():
  if not hasattr(ColorEditFlags_AlphaBar, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_AlphaBar')
    ColorEditFlags_AlphaBar.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_AlphaBar, 'cache'):
    ColorEditFlags_AlphaBar.cache = ColorEditFlags_AlphaBar.func()
  return ColorEditFlags_AlphaBar.cache

def ColorEditFlags_DisplayHSV():
  if not hasattr(ColorEditFlags_DisplayHSV, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_DisplayHSV')
    ColorEditFlags_DisplayHSV.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_DisplayHSV, 'cache'):
    ColorEditFlags_DisplayHSV.cache = ColorEditFlags_DisplayHSV.func()
  return ColorEditFlags_DisplayHSV.cache

def ColorEditFlags_DisplayHex():
  if not hasattr(ColorEditFlags_DisplayHex, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_DisplayHex')
    ColorEditFlags_DisplayHex.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_DisplayHex, 'cache'):
    ColorEditFlags_DisplayHex.cache = ColorEditFlags_DisplayHex.func()
  return ColorEditFlags_DisplayHex.cache

def ColorEditFlags_DisplayRGB():
  if not hasattr(ColorEditFlags_DisplayRGB, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_DisplayRGB')
    ColorEditFlags_DisplayRGB.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_DisplayRGB, 'cache'):
    ColorEditFlags_DisplayRGB.cache = ColorEditFlags_DisplayRGB.func()
  return ColorEditFlags_DisplayRGB.cache

def ColorEditFlags_Float():
  if not hasattr(ColorEditFlags_Float, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_Float')
    ColorEditFlags_Float.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_Float, 'cache'):
    ColorEditFlags_Float.cache = ColorEditFlags_Float.func()
  return ColorEditFlags_Float.cache

def ColorEditFlags_InputHSV():
  if not hasattr(ColorEditFlags_InputHSV, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_InputHSV')
    ColorEditFlags_InputHSV.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_InputHSV, 'cache'):
    ColorEditFlags_InputHSV.cache = ColorEditFlags_InputHSV.func()
  return ColorEditFlags_InputHSV.cache

def ColorEditFlags_InputRGB():
  if not hasattr(ColorEditFlags_InputRGB, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_InputRGB')
    ColorEditFlags_InputRGB.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_InputRGB, 'cache'):
    ColorEditFlags_InputRGB.cache = ColorEditFlags_InputRGB.func()
  return ColorEditFlags_InputRGB.cache

def ColorEditFlags_PickerHueBar():
  if not hasattr(ColorEditFlags_PickerHueBar, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_PickerHueBar')
    ColorEditFlags_PickerHueBar.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_PickerHueBar, 'cache'):
    ColorEditFlags_PickerHueBar.cache = ColorEditFlags_PickerHueBar.func()
  return ColorEditFlags_PickerHueBar.cache

def ColorEditFlags_PickerHueWheel():
  if not hasattr(ColorEditFlags_PickerHueWheel, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_PickerHueWheel')
    ColorEditFlags_PickerHueWheel.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_PickerHueWheel, 'cache'):
    ColorEditFlags_PickerHueWheel.cache = ColorEditFlags_PickerHueWheel.func()
  return ColorEditFlags_PickerHueWheel.cache

def ColorEditFlags_Uint8():
  if not hasattr(ColorEditFlags_Uint8, 'func'):
    proc = rpr_getfp('ImGui_ColorEditFlags_Uint8')
    ColorEditFlags_Uint8.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ColorEditFlags_Uint8, 'cache'):
    ColorEditFlags_Uint8.cache = ColorEditFlags_Uint8.func()
  return ColorEditFlags_Uint8.cache

def BeginCombo(ctx, label, preview_value, flagsInOptional = None):
  if not hasattr(BeginCombo, 'func'):
    proc = rpr_getfp('ImGui_BeginCombo')
    BeginCombo.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), rpr_packsc(preview_value), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = BeginCombo.func(args[0], args[1], args[2], byref(args[3]) if args[3] != None else None)
  return rval

def Combo(ctx, label, current_itemInOut, items, popup_max_height_in_itemsInOptional = None):
  if not hasattr(Combo, 'func'):
    proc = rpr_getfp('ImGui_Combo')
    Combo.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_char_p, c_int, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(current_itemInOut), rpr_packsc(items), c_int(len(items)+1), c_int(popup_max_height_in_itemsInOptional) if popup_max_height_in_itemsInOptional != None else None)
  rval = Combo.func(args[0], args[1], byref(args[2]), args[3], args[4], byref(args[5]) if args[5] != None else None)
  return rval, int(args[2].value)

def ComboFlags_HeightLarge():
  if not hasattr(ComboFlags_HeightLarge, 'func'):
    proc = rpr_getfp('ImGui_ComboFlags_HeightLarge')
    ComboFlags_HeightLarge.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ComboFlags_HeightLarge, 'cache'):
    ComboFlags_HeightLarge.cache = ComboFlags_HeightLarge.func()
  return ComboFlags_HeightLarge.cache

def ComboFlags_HeightLargest():
  if not hasattr(ComboFlags_HeightLargest, 'func'):
    proc = rpr_getfp('ImGui_ComboFlags_HeightLargest')
    ComboFlags_HeightLargest.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ComboFlags_HeightLargest, 'cache'):
    ComboFlags_HeightLargest.cache = ComboFlags_HeightLargest.func()
  return ComboFlags_HeightLargest.cache

def ComboFlags_HeightRegular():
  if not hasattr(ComboFlags_HeightRegular, 'func'):
    proc = rpr_getfp('ImGui_ComboFlags_HeightRegular')
    ComboFlags_HeightRegular.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ComboFlags_HeightRegular, 'cache'):
    ComboFlags_HeightRegular.cache = ComboFlags_HeightRegular.func()
  return ComboFlags_HeightRegular.cache

def ComboFlags_HeightSmall():
  if not hasattr(ComboFlags_HeightSmall, 'func'):
    proc = rpr_getfp('ImGui_ComboFlags_HeightSmall')
    ComboFlags_HeightSmall.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ComboFlags_HeightSmall, 'cache'):
    ComboFlags_HeightSmall.cache = ComboFlags_HeightSmall.func()
  return ComboFlags_HeightSmall.cache

def ComboFlags_NoArrowButton():
  if not hasattr(ComboFlags_NoArrowButton, 'func'):
    proc = rpr_getfp('ImGui_ComboFlags_NoArrowButton')
    ComboFlags_NoArrowButton.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ComboFlags_NoArrowButton, 'cache'):
    ComboFlags_NoArrowButton.cache = ComboFlags_NoArrowButton.func()
  return ComboFlags_NoArrowButton.cache

def ComboFlags_NoPreview():
  if not hasattr(ComboFlags_NoPreview, 'func'):
    proc = rpr_getfp('ImGui_ComboFlags_NoPreview')
    ComboFlags_NoPreview.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ComboFlags_NoPreview, 'cache'):
    ComboFlags_NoPreview.cache = ComboFlags_NoPreview.func()
  return ComboFlags_NoPreview.cache

def ComboFlags_None():
  if not hasattr(ComboFlags_None, 'func'):
    proc = rpr_getfp('ImGui_ComboFlags_None')
    ComboFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ComboFlags_None, 'cache'):
    ComboFlags_None.cache = ComboFlags_None.func()
  return ComboFlags_None.cache

def ComboFlags_PopupAlignLeft():
  if not hasattr(ComboFlags_PopupAlignLeft, 'func'):
    proc = rpr_getfp('ImGui_ComboFlags_PopupAlignLeft')
    ComboFlags_PopupAlignLeft.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ComboFlags_PopupAlignLeft, 'cache'):
    ComboFlags_PopupAlignLeft.cache = ComboFlags_PopupAlignLeft.func()
  return ComboFlags_PopupAlignLeft.cache

def ComboFlags_WidthFitPreview():
  if not hasattr(ComboFlags_WidthFitPreview, 'func'):
    proc = rpr_getfp('ImGui_ComboFlags_WidthFitPreview')
    ComboFlags_WidthFitPreview.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ComboFlags_WidthFitPreview, 'cache'):
    ComboFlags_WidthFitPreview.cache = ComboFlags_WidthFitPreview.func()
  return ComboFlags_WidthFitPreview.cache

def EndCombo(ctx):
  if not hasattr(EndCombo, 'func'):
    proc = rpr_getfp('ImGui_EndCombo')
    EndCombo.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  EndCombo.func(args[0])

def BeginListBox(ctx, label, size_wInOptional = None, size_hInOptional = None):
  if not hasattr(BeginListBox, 'func'):
    proc = rpr_getfp('ImGui_BeginListBox')
    BeginListBox.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_double(size_wInOptional) if size_wInOptional != None else None, c_double(size_hInOptional) if size_hInOptional != None else None)
  rval = BeginListBox.func(args[0], args[1], byref(args[2]) if args[2] != None else None, byref(args[3]) if args[3] != None else None)
  return rval

def EndListBox(ctx):
  if not hasattr(EndListBox, 'func'):
    proc = rpr_getfp('ImGui_EndListBox')
    EndListBox.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  EndListBox.func(args[0])

def ListBox(ctx, label, current_itemInOut, items, height_in_itemsInOptional = None):
  if not hasattr(ListBox, 'func'):
    proc = rpr_getfp('ImGui_ListBox')
    ListBox.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_char_p, c_int, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(current_itemInOut), rpr_packsc(items), c_int(len(items)+1), c_int(height_in_itemsInOptional) if height_in_itemsInOptional != None else None)
  rval = ListBox.func(args[0], args[1], byref(args[2]), args[3], args[4], byref(args[5]) if args[5] != None else None)
  return rval, int(args[2].value)

def Selectable(ctx, label, p_selectedInOutOptional = None, flagsInOptional = None, size_wInOptional = None, size_hInOptional = None):
  if not hasattr(Selectable, 'func'):
    proc = rpr_getfp('ImGui_Selectable')
    Selectable.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_bool(p_selectedInOutOptional) if p_selectedInOutOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None, c_double(size_wInOptional) if size_wInOptional != None else None, c_double(size_hInOptional) if size_hInOptional != None else None)
  rval = Selectable.func(args[0], args[1], byref(args[2]) if args[2] != None else None, byref(args[3]) if args[3] != None else None, byref(args[4]) if args[4] != None else None, byref(args[5]) if args[5] != None else None)
  return rval, int(args[2].value) if p_selectedInOutOptional != None else None

def SelectableFlags_AllowDoubleClick():
  if not hasattr(SelectableFlags_AllowDoubleClick, 'func'):
    proc = rpr_getfp('ImGui_SelectableFlags_AllowDoubleClick')
    SelectableFlags_AllowDoubleClick.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(SelectableFlags_AllowDoubleClick, 'cache'):
    SelectableFlags_AllowDoubleClick.cache = SelectableFlags_AllowDoubleClick.func()
  return SelectableFlags_AllowDoubleClick.cache

def SelectableFlags_AllowOverlap():
  if not hasattr(SelectableFlags_AllowOverlap, 'func'):
    proc = rpr_getfp('ImGui_SelectableFlags_AllowOverlap')
    SelectableFlags_AllowOverlap.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(SelectableFlags_AllowOverlap, 'cache'):
    SelectableFlags_AllowOverlap.cache = SelectableFlags_AllowOverlap.func()
  return SelectableFlags_AllowOverlap.cache

def SelectableFlags_Disabled():
  if not hasattr(SelectableFlags_Disabled, 'func'):
    proc = rpr_getfp('ImGui_SelectableFlags_Disabled')
    SelectableFlags_Disabled.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(SelectableFlags_Disabled, 'cache'):
    SelectableFlags_Disabled.cache = SelectableFlags_Disabled.func()
  return SelectableFlags_Disabled.cache

def SelectableFlags_Highlight():
  if not hasattr(SelectableFlags_Highlight, 'func'):
    proc = rpr_getfp('ImGui_SelectableFlags_Highlight')
    SelectableFlags_Highlight.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(SelectableFlags_Highlight, 'cache'):
    SelectableFlags_Highlight.cache = SelectableFlags_Highlight.func()
  return SelectableFlags_Highlight.cache

def SelectableFlags_NoAutoClosePopups():
  if not hasattr(SelectableFlags_NoAutoClosePopups, 'func'):
    proc = rpr_getfp('ImGui_SelectableFlags_NoAutoClosePopups')
    SelectableFlags_NoAutoClosePopups.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(SelectableFlags_NoAutoClosePopups, 'cache'):
    SelectableFlags_NoAutoClosePopups.cache = SelectableFlags_NoAutoClosePopups.func()
  return SelectableFlags_NoAutoClosePopups.cache

def SelectableFlags_None():
  if not hasattr(SelectableFlags_None, 'func'):
    proc = rpr_getfp('ImGui_SelectableFlags_None')
    SelectableFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(SelectableFlags_None, 'cache'):
    SelectableFlags_None.cache = SelectableFlags_None.func()
  return SelectableFlags_None.cache

def SelectableFlags_SpanAllColumns():
  if not hasattr(SelectableFlags_SpanAllColumns, 'func'):
    proc = rpr_getfp('ImGui_SelectableFlags_SpanAllColumns')
    SelectableFlags_SpanAllColumns.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(SelectableFlags_SpanAllColumns, 'cache'):
    SelectableFlags_SpanAllColumns.cache = SelectableFlags_SpanAllColumns.func()
  return SelectableFlags_SpanAllColumns.cache

def Attach(ctx, obj):
  if not hasattr(Attach, 'func'):
    proc = rpr_getfp('ImGui_Attach')
    Attach.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_void_p(obj))
  Attach.func(args[0], args[1])

def CreateContext(label, config_flagsInOptional = None):
  if not hasattr(CreateContext, 'func'):
    proc = rpr_getfp('ImGui_CreateContext')
    CreateContext.func = CFUNCTYPE(c_void_p, c_char_p, c_void_p)(proc)
  args = (rpr_packsc(label), c_int(config_flagsInOptional) if config_flagsInOptional != None else None)
  rval = CreateContext.func(args[0], byref(args[1]) if args[1] != None else None)
  return rval

def Detach(ctx, obj):
  if not hasattr(Detach, 'func'):
    proc = rpr_getfp('ImGui_Detach')
    Detach.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_void_p(obj))
  Detach.func(args[0], args[1])

def GetDeltaTime(ctx):
  if not hasattr(GetDeltaTime, 'func'):
    proc = rpr_getfp('ImGui_GetDeltaTime')
    GetDeltaTime.func = CFUNCTYPE(c_double, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetDeltaTime.func(args[0])
  return rval

def GetFrameCount(ctx):
  if not hasattr(GetFrameCount, 'func'):
    proc = rpr_getfp('ImGui_GetFrameCount')
    GetFrameCount.func = CFUNCTYPE(c_int, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetFrameCount.func(args[0])
  return rval

def GetFramerate(ctx):
  if not hasattr(GetFramerate, 'func'):
    proc = rpr_getfp('ImGui_GetFramerate')
    GetFramerate.func = CFUNCTYPE(c_double, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetFramerate.func(args[0])
  return rval

def GetTime(ctx):
  if not hasattr(GetTime, 'func'):
    proc = rpr_getfp('ImGui_GetTime')
    GetTime.func = CFUNCTYPE(c_double, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetTime.func(args[0])
  return rval

def ConfigFlags_DockingEnable():
  if not hasattr(ConfigFlags_DockingEnable, 'func'):
    proc = rpr_getfp('ImGui_ConfigFlags_DockingEnable')
    ConfigFlags_DockingEnable.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigFlags_DockingEnable, 'cache'):
    ConfigFlags_DockingEnable.cache = ConfigFlags_DockingEnable.func()
  return ConfigFlags_DockingEnable.cache

def ConfigFlags_NavEnableKeyboard():
  if not hasattr(ConfigFlags_NavEnableKeyboard, 'func'):
    proc = rpr_getfp('ImGui_ConfigFlags_NavEnableKeyboard')
    ConfigFlags_NavEnableKeyboard.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigFlags_NavEnableKeyboard, 'cache'):
    ConfigFlags_NavEnableKeyboard.cache = ConfigFlags_NavEnableKeyboard.func()
  return ConfigFlags_NavEnableKeyboard.cache

def ConfigFlags_NoKeyboard():
  if not hasattr(ConfigFlags_NoKeyboard, 'func'):
    proc = rpr_getfp('ImGui_ConfigFlags_NoKeyboard')
    ConfigFlags_NoKeyboard.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigFlags_NoKeyboard, 'cache'):
    ConfigFlags_NoKeyboard.cache = ConfigFlags_NoKeyboard.func()
  return ConfigFlags_NoKeyboard.cache

def ConfigFlags_NoMouse():
  if not hasattr(ConfigFlags_NoMouse, 'func'):
    proc = rpr_getfp('ImGui_ConfigFlags_NoMouse')
    ConfigFlags_NoMouse.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigFlags_NoMouse, 'cache'):
    ConfigFlags_NoMouse.cache = ConfigFlags_NoMouse.func()
  return ConfigFlags_NoMouse.cache

def ConfigFlags_NoMouseCursorChange():
  if not hasattr(ConfigFlags_NoMouseCursorChange, 'func'):
    proc = rpr_getfp('ImGui_ConfigFlags_NoMouseCursorChange')
    ConfigFlags_NoMouseCursorChange.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigFlags_NoMouseCursorChange, 'cache'):
    ConfigFlags_NoMouseCursorChange.cache = ConfigFlags_NoMouseCursorChange.func()
  return ConfigFlags_NoMouseCursorChange.cache

def ConfigFlags_NoSavedSettings():
  if not hasattr(ConfigFlags_NoSavedSettings, 'func'):
    proc = rpr_getfp('ImGui_ConfigFlags_NoSavedSettings')
    ConfigFlags_NoSavedSettings.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigFlags_NoSavedSettings, 'cache'):
    ConfigFlags_NoSavedSettings.cache = ConfigFlags_NoSavedSettings.func()
  return ConfigFlags_NoSavedSettings.cache

def ConfigFlags_None():
  if not hasattr(ConfigFlags_None, 'func'):
    proc = rpr_getfp('ImGui_ConfigFlags_None')
    ConfigFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigFlags_None, 'cache'):
    ConfigFlags_None.cache = ConfigFlags_None.func()
  return ConfigFlags_None.cache

def ConfigVar_DebugBeginReturnValueLoop():
  if not hasattr(ConfigVar_DebugBeginReturnValueLoop, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_DebugBeginReturnValueLoop')
    ConfigVar_DebugBeginReturnValueLoop.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_DebugBeginReturnValueLoop, 'cache'):
    ConfigVar_DebugBeginReturnValueLoop.cache = ConfigVar_DebugBeginReturnValueLoop.func()
  return ConfigVar_DebugBeginReturnValueLoop.cache

def ConfigVar_DebugBeginReturnValueOnce():
  if not hasattr(ConfigVar_DebugBeginReturnValueOnce, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_DebugBeginReturnValueOnce')
    ConfigVar_DebugBeginReturnValueOnce.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_DebugBeginReturnValueOnce, 'cache'):
    ConfigVar_DebugBeginReturnValueOnce.cache = ConfigVar_DebugBeginReturnValueOnce.func()
  return ConfigVar_DebugBeginReturnValueOnce.cache

def ConfigVar_DebugHighlightIdConflicts():
  if not hasattr(ConfigVar_DebugHighlightIdConflicts, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_DebugHighlightIdConflicts')
    ConfigVar_DebugHighlightIdConflicts.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_DebugHighlightIdConflicts, 'cache'):
    ConfigVar_DebugHighlightIdConflicts.cache = ConfigVar_DebugHighlightIdConflicts.func()
  return ConfigVar_DebugHighlightIdConflicts.cache

def ConfigVar_DockingNoSplit():
  if not hasattr(ConfigVar_DockingNoSplit, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_DockingNoSplit')
    ConfigVar_DockingNoSplit.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_DockingNoSplit, 'cache'):
    ConfigVar_DockingNoSplit.cache = ConfigVar_DockingNoSplit.func()
  return ConfigVar_DockingNoSplit.cache

def ConfigVar_DockingTransparentPayload():
  if not hasattr(ConfigVar_DockingTransparentPayload, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_DockingTransparentPayload')
    ConfigVar_DockingTransparentPayload.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_DockingTransparentPayload, 'cache'):
    ConfigVar_DockingTransparentPayload.cache = ConfigVar_DockingTransparentPayload.func()
  return ConfigVar_DockingTransparentPayload.cache

def ConfigVar_DockingWithShift():
  if not hasattr(ConfigVar_DockingWithShift, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_DockingWithShift')
    ConfigVar_DockingWithShift.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_DockingWithShift, 'cache'):
    ConfigVar_DockingWithShift.cache = ConfigVar_DockingWithShift.func()
  return ConfigVar_DockingWithShift.cache

def ConfigVar_DragClickToInputText():
  if not hasattr(ConfigVar_DragClickToInputText, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_DragClickToInputText')
    ConfigVar_DragClickToInputText.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_DragClickToInputText, 'cache'):
    ConfigVar_DragClickToInputText.cache = ConfigVar_DragClickToInputText.func()
  return ConfigVar_DragClickToInputText.cache

def ConfigVar_Flags():
  if not hasattr(ConfigVar_Flags, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_Flags')
    ConfigVar_Flags.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_Flags, 'cache'):
    ConfigVar_Flags.cache = ConfigVar_Flags.func()
  return ConfigVar_Flags.cache

def ConfigVar_HoverDelayNormal():
  if not hasattr(ConfigVar_HoverDelayNormal, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_HoverDelayNormal')
    ConfigVar_HoverDelayNormal.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_HoverDelayNormal, 'cache'):
    ConfigVar_HoverDelayNormal.cache = ConfigVar_HoverDelayNormal.func()
  return ConfigVar_HoverDelayNormal.cache

def ConfigVar_HoverDelayShort():
  if not hasattr(ConfigVar_HoverDelayShort, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_HoverDelayShort')
    ConfigVar_HoverDelayShort.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_HoverDelayShort, 'cache'):
    ConfigVar_HoverDelayShort.cache = ConfigVar_HoverDelayShort.func()
  return ConfigVar_HoverDelayShort.cache

def ConfigVar_HoverFlagsForTooltipMouse():
  if not hasattr(ConfigVar_HoverFlagsForTooltipMouse, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_HoverFlagsForTooltipMouse')
    ConfigVar_HoverFlagsForTooltipMouse.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_HoverFlagsForTooltipMouse, 'cache'):
    ConfigVar_HoverFlagsForTooltipMouse.cache = ConfigVar_HoverFlagsForTooltipMouse.func()
  return ConfigVar_HoverFlagsForTooltipMouse.cache

def ConfigVar_HoverFlagsForTooltipNav():
  if not hasattr(ConfigVar_HoverFlagsForTooltipNav, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_HoverFlagsForTooltipNav')
    ConfigVar_HoverFlagsForTooltipNav.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_HoverFlagsForTooltipNav, 'cache'):
    ConfigVar_HoverFlagsForTooltipNav.cache = ConfigVar_HoverFlagsForTooltipNav.func()
  return ConfigVar_HoverFlagsForTooltipNav.cache

def ConfigVar_HoverStationaryDelay():
  if not hasattr(ConfigVar_HoverStationaryDelay, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_HoverStationaryDelay')
    ConfigVar_HoverStationaryDelay.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_HoverStationaryDelay, 'cache'):
    ConfigVar_HoverStationaryDelay.cache = ConfigVar_HoverStationaryDelay.func()
  return ConfigVar_HoverStationaryDelay.cache

def ConfigVar_InputTextCursorBlink():
  if not hasattr(ConfigVar_InputTextCursorBlink, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_InputTextCursorBlink')
    ConfigVar_InputTextCursorBlink.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_InputTextCursorBlink, 'cache'):
    ConfigVar_InputTextCursorBlink.cache = ConfigVar_InputTextCursorBlink.func()
  return ConfigVar_InputTextCursorBlink.cache

def ConfigVar_InputTextEnterKeepActive():
  if not hasattr(ConfigVar_InputTextEnterKeepActive, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_InputTextEnterKeepActive')
    ConfigVar_InputTextEnterKeepActive.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_InputTextEnterKeepActive, 'cache'):
    ConfigVar_InputTextEnterKeepActive.cache = ConfigVar_InputTextEnterKeepActive.func()
  return ConfigVar_InputTextEnterKeepActive.cache

def ConfigVar_InputTrickleEventQueue():
  if not hasattr(ConfigVar_InputTrickleEventQueue, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_InputTrickleEventQueue')
    ConfigVar_InputTrickleEventQueue.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_InputTrickleEventQueue, 'cache'):
    ConfigVar_InputTrickleEventQueue.cache = ConfigVar_InputTrickleEventQueue.func()
  return ConfigVar_InputTrickleEventQueue.cache

def ConfigVar_KeyRepeatDelay():
  if not hasattr(ConfigVar_KeyRepeatDelay, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_KeyRepeatDelay')
    ConfigVar_KeyRepeatDelay.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_KeyRepeatDelay, 'cache'):
    ConfigVar_KeyRepeatDelay.cache = ConfigVar_KeyRepeatDelay.func()
  return ConfigVar_KeyRepeatDelay.cache

def ConfigVar_KeyRepeatRate():
  if not hasattr(ConfigVar_KeyRepeatRate, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_KeyRepeatRate')
    ConfigVar_KeyRepeatRate.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_KeyRepeatRate, 'cache'):
    ConfigVar_KeyRepeatRate.cache = ConfigVar_KeyRepeatRate.func()
  return ConfigVar_KeyRepeatRate.cache

def ConfigVar_MacOSXBehaviors():
  if not hasattr(ConfigVar_MacOSXBehaviors, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_MacOSXBehaviors')
    ConfigVar_MacOSXBehaviors.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_MacOSXBehaviors, 'cache'):
    ConfigVar_MacOSXBehaviors.cache = ConfigVar_MacOSXBehaviors.func()
  return ConfigVar_MacOSXBehaviors.cache

def ConfigVar_MouseDoubleClickMaxDist():
  if not hasattr(ConfigVar_MouseDoubleClickMaxDist, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_MouseDoubleClickMaxDist')
    ConfigVar_MouseDoubleClickMaxDist.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_MouseDoubleClickMaxDist, 'cache'):
    ConfigVar_MouseDoubleClickMaxDist.cache = ConfigVar_MouseDoubleClickMaxDist.func()
  return ConfigVar_MouseDoubleClickMaxDist.cache

def ConfigVar_MouseDoubleClickTime():
  if not hasattr(ConfigVar_MouseDoubleClickTime, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_MouseDoubleClickTime')
    ConfigVar_MouseDoubleClickTime.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_MouseDoubleClickTime, 'cache'):
    ConfigVar_MouseDoubleClickTime.cache = ConfigVar_MouseDoubleClickTime.func()
  return ConfigVar_MouseDoubleClickTime.cache

def ConfigVar_MouseDragThreshold():
  if not hasattr(ConfigVar_MouseDragThreshold, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_MouseDragThreshold')
    ConfigVar_MouseDragThreshold.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_MouseDragThreshold, 'cache'):
    ConfigVar_MouseDragThreshold.cache = ConfigVar_MouseDragThreshold.func()
  return ConfigVar_MouseDragThreshold.cache

def ConfigVar_NavCaptureKeyboard():
  if not hasattr(ConfigVar_NavCaptureKeyboard, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_NavCaptureKeyboard')
    ConfigVar_NavCaptureKeyboard.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_NavCaptureKeyboard, 'cache'):
    ConfigVar_NavCaptureKeyboard.cache = ConfigVar_NavCaptureKeyboard.func()
  return ConfigVar_NavCaptureKeyboard.cache

def ConfigVar_NavCursorVisibleAlways():
  if not hasattr(ConfigVar_NavCursorVisibleAlways, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_NavCursorVisibleAlways')
    ConfigVar_NavCursorVisibleAlways.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_NavCursorVisibleAlways, 'cache'):
    ConfigVar_NavCursorVisibleAlways.cache = ConfigVar_NavCursorVisibleAlways.func()
  return ConfigVar_NavCursorVisibleAlways.cache

def ConfigVar_NavCursorVisibleAuto():
  if not hasattr(ConfigVar_NavCursorVisibleAuto, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_NavCursorVisibleAuto')
    ConfigVar_NavCursorVisibleAuto.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_NavCursorVisibleAuto, 'cache'):
    ConfigVar_NavCursorVisibleAuto.cache = ConfigVar_NavCursorVisibleAuto.func()
  return ConfigVar_NavCursorVisibleAuto.cache

def ConfigVar_NavEscapeClearFocusItem():
  if not hasattr(ConfigVar_NavEscapeClearFocusItem, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_NavEscapeClearFocusItem')
    ConfigVar_NavEscapeClearFocusItem.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_NavEscapeClearFocusItem, 'cache'):
    ConfigVar_NavEscapeClearFocusItem.cache = ConfigVar_NavEscapeClearFocusItem.func()
  return ConfigVar_NavEscapeClearFocusItem.cache

def ConfigVar_NavEscapeClearFocusWindow():
  if not hasattr(ConfigVar_NavEscapeClearFocusWindow, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_NavEscapeClearFocusWindow')
    ConfigVar_NavEscapeClearFocusWindow.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_NavEscapeClearFocusWindow, 'cache'):
    ConfigVar_NavEscapeClearFocusWindow.cache = ConfigVar_NavEscapeClearFocusWindow.func()
  return ConfigVar_NavEscapeClearFocusWindow.cache

def ConfigVar_NavMoveSetMousePos():
  if not hasattr(ConfigVar_NavMoveSetMousePos, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_NavMoveSetMousePos')
    ConfigVar_NavMoveSetMousePos.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_NavMoveSetMousePos, 'cache'):
    ConfigVar_NavMoveSetMousePos.cache = ConfigVar_NavMoveSetMousePos.func()
  return ConfigVar_NavMoveSetMousePos.cache

def ConfigVar_ScrollbarScrollByPage():
  if not hasattr(ConfigVar_ScrollbarScrollByPage, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_ScrollbarScrollByPage')
    ConfigVar_ScrollbarScrollByPage.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_ScrollbarScrollByPage, 'cache'):
    ConfigVar_ScrollbarScrollByPage.cache = ConfigVar_ScrollbarScrollByPage.func()
  return ConfigVar_ScrollbarScrollByPage.cache

def ConfigVar_ViewportsNoDecoration():
  if not hasattr(ConfigVar_ViewportsNoDecoration, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_ViewportsNoDecoration')
    ConfigVar_ViewportsNoDecoration.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_ViewportsNoDecoration, 'cache'):
    ConfigVar_ViewportsNoDecoration.cache = ConfigVar_ViewportsNoDecoration.func()
  return ConfigVar_ViewportsNoDecoration.cache

def ConfigVar_WindowsMoveFromTitleBarOnly():
  if not hasattr(ConfigVar_WindowsMoveFromTitleBarOnly, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_WindowsMoveFromTitleBarOnly')
    ConfigVar_WindowsMoveFromTitleBarOnly.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_WindowsMoveFromTitleBarOnly, 'cache'):
    ConfigVar_WindowsMoveFromTitleBarOnly.cache = ConfigVar_WindowsMoveFromTitleBarOnly.func()
  return ConfigVar_WindowsMoveFromTitleBarOnly.cache

def ConfigVar_WindowsResizeFromEdges():
  if not hasattr(ConfigVar_WindowsResizeFromEdges, 'func'):
    proc = rpr_getfp('ImGui_ConfigVar_WindowsResizeFromEdges')
    ConfigVar_WindowsResizeFromEdges.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ConfigVar_WindowsResizeFromEdges, 'cache'):
    ConfigVar_WindowsResizeFromEdges.cache = ConfigVar_WindowsResizeFromEdges.func()
  return ConfigVar_WindowsResizeFromEdges.cache

def GetConfigVar(ctx, var_idx):
  if not hasattr(GetConfigVar, 'func'):
    proc = rpr_getfp('ImGui_GetConfigVar')
    GetConfigVar.func = CFUNCTYPE(c_double, c_void_p, c_int)(proc)
  args = (c_void_p(ctx), c_int(var_idx))
  rval = GetConfigVar.func(args[0], args[1])
  return rval

def SetConfigVar(ctx, var_idx, value):
  if not hasattr(SetConfigVar, 'func'):
    proc = rpr_getfp('ImGui_SetConfigVar')
    SetConfigVar.func = CFUNCTYPE(None, c_void_p, c_int, c_double)(proc)
  args = (c_void_p(ctx), c_int(var_idx), c_double(value))
  SetConfigVar.func(args[0], args[1], args[2])

def AcceptDragDropPayload(ctx, type, flagsInOptional = None):
  if not hasattr(AcceptDragDropPayload, 'func'):
    proc = rpr_getfp('ImGui_AcceptDragDropPayload')
    AcceptDragDropPayload.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_char_p, c_int, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(type), rpr_packs(0), c_int(4096), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = AcceptDragDropPayload.func(args[0], args[1], args[2], args[3], byref(args[4]) if args[4] != None else None)
  return rval, rpr_unpacks(args[2])

def AcceptDragDropPayloadFiles(ctx, flagsInOptional = None):
  if not hasattr(AcceptDragDropPayloadFiles, 'func'):
    proc = rpr_getfp('ImGui_AcceptDragDropPayloadFiles')
    AcceptDragDropPayloadFiles.func = CFUNCTYPE(c_bool, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(0), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = AcceptDragDropPayloadFiles.func(args[0], byref(args[1]), byref(args[2]) if args[2] != None else None)
  return rval, int(args[1].value)

def AcceptDragDropPayloadRGB(ctx, flagsInOptional = None):
  if not hasattr(AcceptDragDropPayloadRGB, 'func'):
    proc = rpr_getfp('ImGui_AcceptDragDropPayloadRGB')
    AcceptDragDropPayloadRGB.func = CFUNCTYPE(c_bool, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(0), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = AcceptDragDropPayloadRGB.func(args[0], byref(args[1]), byref(args[2]) if args[2] != None else None)
  return rval, int(args[1].value)

def AcceptDragDropPayloadRGBA(ctx, flagsInOptional = None):
  if not hasattr(AcceptDragDropPayloadRGBA, 'func'):
    proc = rpr_getfp('ImGui_AcceptDragDropPayloadRGBA')
    AcceptDragDropPayloadRGBA.func = CFUNCTYPE(c_bool, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(0), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = AcceptDragDropPayloadRGBA.func(args[0], byref(args[1]), byref(args[2]) if args[2] != None else None)
  return rval, int(args[1].value)

def BeginDragDropSource(ctx, flagsInOptional = None):
  if not hasattr(BeginDragDropSource, 'func'):
    proc = rpr_getfp('ImGui_BeginDragDropSource')
    BeginDragDropSource.func = CFUNCTYPE(c_bool, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = BeginDragDropSource.func(args[0], byref(args[1]) if args[1] != None else None)
  return rval

def BeginDragDropTarget(ctx):
  if not hasattr(BeginDragDropTarget, 'func'):
    proc = rpr_getfp('ImGui_BeginDragDropTarget')
    BeginDragDropTarget.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = BeginDragDropTarget.func(args[0])
  return rval

def EndDragDropSource(ctx):
  if not hasattr(EndDragDropSource, 'func'):
    proc = rpr_getfp('ImGui_EndDragDropSource')
    EndDragDropSource.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  EndDragDropSource.func(args[0])

def EndDragDropTarget(ctx):
  if not hasattr(EndDragDropTarget, 'func'):
    proc = rpr_getfp('ImGui_EndDragDropTarget')
    EndDragDropTarget.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  EndDragDropTarget.func(args[0])

def GetDragDropPayload(ctx):
  if not hasattr(GetDragDropPayload, 'func'):
    proc = rpr_getfp('ImGui_GetDragDropPayload')
    GetDragDropPayload.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_int, c_char_p, c_int, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packs(0), c_int(1024), rpr_packs(0), c_int(4096), c_bool(0), c_bool(0))
  rval = GetDragDropPayload.func(args[0], args[1], args[2], args[3], args[4], byref(args[5]), byref(args[6]))
  return rval, rpr_unpacks(args[1]), rpr_unpacks(args[3]), int(args[5].value), int(args[6].value)

def GetDragDropPayloadFile(ctx, index):
  if not hasattr(GetDragDropPayloadFile, 'func'):
    proc = rpr_getfp('ImGui_GetDragDropPayloadFile')
    GetDragDropPayloadFile.func = CFUNCTYPE(c_bool, c_void_p, c_int, c_char_p, c_int)(proc)
  args = (c_void_p(ctx), c_int(index), rpr_packs(0), c_int(1024))
  rval = GetDragDropPayloadFile.func(args[0], args[1], args[2], args[3])
  return rval, rpr_unpacks(args[2])

def SetDragDropPayload(ctx, type, data, condInOptional = None):
  if not hasattr(SetDragDropPayload, 'func'):
    proc = rpr_getfp('ImGui_SetDragDropPayload')
    SetDragDropPayload.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(type), rpr_packsc(data), c_int(condInOptional) if condInOptional != None else None)
  rval = SetDragDropPayload.func(args[0], args[1], args[2], byref(args[3]) if args[3] != None else None)
  return rval

def DragDropFlags_None():
  if not hasattr(DragDropFlags_None, 'func'):
    proc = rpr_getfp('ImGui_DragDropFlags_None')
    DragDropFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DragDropFlags_None, 'cache'):
    DragDropFlags_None.cache = DragDropFlags_None.func()
  return DragDropFlags_None.cache

def DragDropFlags_AcceptBeforeDelivery():
  if not hasattr(DragDropFlags_AcceptBeforeDelivery, 'func'):
    proc = rpr_getfp('ImGui_DragDropFlags_AcceptBeforeDelivery')
    DragDropFlags_AcceptBeforeDelivery.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DragDropFlags_AcceptBeforeDelivery, 'cache'):
    DragDropFlags_AcceptBeforeDelivery.cache = DragDropFlags_AcceptBeforeDelivery.func()
  return DragDropFlags_AcceptBeforeDelivery.cache

def DragDropFlags_AcceptNoDrawDefaultRect():
  if not hasattr(DragDropFlags_AcceptNoDrawDefaultRect, 'func'):
    proc = rpr_getfp('ImGui_DragDropFlags_AcceptNoDrawDefaultRect')
    DragDropFlags_AcceptNoDrawDefaultRect.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DragDropFlags_AcceptNoDrawDefaultRect, 'cache'):
    DragDropFlags_AcceptNoDrawDefaultRect.cache = DragDropFlags_AcceptNoDrawDefaultRect.func()
  return DragDropFlags_AcceptNoDrawDefaultRect.cache

def DragDropFlags_AcceptNoPreviewTooltip():
  if not hasattr(DragDropFlags_AcceptNoPreviewTooltip, 'func'):
    proc = rpr_getfp('ImGui_DragDropFlags_AcceptNoPreviewTooltip')
    DragDropFlags_AcceptNoPreviewTooltip.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DragDropFlags_AcceptNoPreviewTooltip, 'cache'):
    DragDropFlags_AcceptNoPreviewTooltip.cache = DragDropFlags_AcceptNoPreviewTooltip.func()
  return DragDropFlags_AcceptNoPreviewTooltip.cache

def DragDropFlags_AcceptPeekOnly():
  if not hasattr(DragDropFlags_AcceptPeekOnly, 'func'):
    proc = rpr_getfp('ImGui_DragDropFlags_AcceptPeekOnly')
    DragDropFlags_AcceptPeekOnly.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DragDropFlags_AcceptPeekOnly, 'cache'):
    DragDropFlags_AcceptPeekOnly.cache = DragDropFlags_AcceptPeekOnly.func()
  return DragDropFlags_AcceptPeekOnly.cache

def DragDropFlags_PayloadAutoExpire():
  if not hasattr(DragDropFlags_PayloadAutoExpire, 'func'):
    proc = rpr_getfp('ImGui_DragDropFlags_PayloadAutoExpire')
    DragDropFlags_PayloadAutoExpire.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DragDropFlags_PayloadAutoExpire, 'cache'):
    DragDropFlags_PayloadAutoExpire.cache = DragDropFlags_PayloadAutoExpire.func()
  return DragDropFlags_PayloadAutoExpire.cache

def DragDropFlags_SourceAllowNullID():
  if not hasattr(DragDropFlags_SourceAllowNullID, 'func'):
    proc = rpr_getfp('ImGui_DragDropFlags_SourceAllowNullID')
    DragDropFlags_SourceAllowNullID.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DragDropFlags_SourceAllowNullID, 'cache'):
    DragDropFlags_SourceAllowNullID.cache = DragDropFlags_SourceAllowNullID.func()
  return DragDropFlags_SourceAllowNullID.cache

def DragDropFlags_SourceExtern():
  if not hasattr(DragDropFlags_SourceExtern, 'func'):
    proc = rpr_getfp('ImGui_DragDropFlags_SourceExtern')
    DragDropFlags_SourceExtern.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DragDropFlags_SourceExtern, 'cache'):
    DragDropFlags_SourceExtern.cache = DragDropFlags_SourceExtern.func()
  return DragDropFlags_SourceExtern.cache

def DragDropFlags_SourceNoDisableHover():
  if not hasattr(DragDropFlags_SourceNoDisableHover, 'func'):
    proc = rpr_getfp('ImGui_DragDropFlags_SourceNoDisableHover')
    DragDropFlags_SourceNoDisableHover.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DragDropFlags_SourceNoDisableHover, 'cache'):
    DragDropFlags_SourceNoDisableHover.cache = DragDropFlags_SourceNoDisableHover.func()
  return DragDropFlags_SourceNoDisableHover.cache

def DragDropFlags_SourceNoHoldToOpenOthers():
  if not hasattr(DragDropFlags_SourceNoHoldToOpenOthers, 'func'):
    proc = rpr_getfp('ImGui_DragDropFlags_SourceNoHoldToOpenOthers')
    DragDropFlags_SourceNoHoldToOpenOthers.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DragDropFlags_SourceNoHoldToOpenOthers, 'cache'):
    DragDropFlags_SourceNoHoldToOpenOthers.cache = DragDropFlags_SourceNoHoldToOpenOthers.func()
  return DragDropFlags_SourceNoHoldToOpenOthers.cache

def DragDropFlags_SourceNoPreviewTooltip():
  if not hasattr(DragDropFlags_SourceNoPreviewTooltip, 'func'):
    proc = rpr_getfp('ImGui_DragDropFlags_SourceNoPreviewTooltip')
    DragDropFlags_SourceNoPreviewTooltip.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DragDropFlags_SourceNoPreviewTooltip, 'cache'):
    DragDropFlags_SourceNoPreviewTooltip.cache = DragDropFlags_SourceNoPreviewTooltip.func()
  return DragDropFlags_SourceNoPreviewTooltip.cache

def DragDouble(ctx, label, vInOut, v_speedInOptional = None, v_minInOptional = None, v_maxInOptional = None, formatInOptional = None, flagsInOptional = None):
  if not hasattr(DragDouble, 'func'):
    proc = rpr_getfp('ImGui_DragDouble')
    DragDouble.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_double(vInOut), c_double(v_speedInOptional) if v_speedInOptional != None else None, c_double(v_minInOptional) if v_minInOptional != None else None, c_double(v_maxInOptional) if v_maxInOptional != None else None, rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = DragDouble.func(args[0], args[1], byref(args[2]), byref(args[3]) if args[3] != None else None, byref(args[4]) if args[4] != None else None, byref(args[5]) if args[5] != None else None, args[6], byref(args[7]) if args[7] != None else None)
  return rval, float(args[2].value)

def DragDouble2(ctx, label, v1InOut, v2InOut, v_speedInOptional = None, v_minInOptional = None, v_maxInOptional = None, formatInOptional = None, flagsInOptional = None):
  if not hasattr(DragDouble2, 'func'):
    proc = rpr_getfp('ImGui_DragDouble2')
    DragDouble2.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_double(v1InOut), c_double(v2InOut), c_double(v_speedInOptional) if v_speedInOptional != None else None, c_double(v_minInOptional) if v_minInOptional != None else None, c_double(v_maxInOptional) if v_maxInOptional != None else None, rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = DragDouble2.func(args[0], args[1], byref(args[2]), byref(args[3]), byref(args[4]) if args[4] != None else None, byref(args[5]) if args[5] != None else None, byref(args[6]) if args[6] != None else None, args[7], byref(args[8]) if args[8] != None else None)
  return rval, float(args[2].value), float(args[3].value)

def DragDouble3(ctx, label, v1InOut, v2InOut, v3InOut, v_speedInOptional = None, v_minInOptional = None, v_maxInOptional = None, formatInOptional = None, flagsInOptional = None):
  if not hasattr(DragDouble3, 'func'):
    proc = rpr_getfp('ImGui_DragDouble3')
    DragDouble3.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_double(v1InOut), c_double(v2InOut), c_double(v3InOut), c_double(v_speedInOptional) if v_speedInOptional != None else None, c_double(v_minInOptional) if v_minInOptional != None else None, c_double(v_maxInOptional) if v_maxInOptional != None else None, rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = DragDouble3.func(args[0], args[1], byref(args[2]), byref(args[3]), byref(args[4]), byref(args[5]) if args[5] != None else None, byref(args[6]) if args[6] != None else None, byref(args[7]) if args[7] != None else None, args[8], byref(args[9]) if args[9] != None else None)
  return rval, float(args[2].value), float(args[3].value), float(args[4].value)

def DragDouble4(ctx, label, v1InOut, v2InOut, v3InOut, v4InOut, v_speedInOptional = None, v_minInOptional = None, v_maxInOptional = None, formatInOptional = None, flagsInOptional = None):
  if not hasattr(DragDouble4, 'func'):
    proc = rpr_getfp('ImGui_DragDouble4')
    DragDouble4.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_double(v1InOut), c_double(v2InOut), c_double(v3InOut), c_double(v4InOut), c_double(v_speedInOptional) if v_speedInOptional != None else None, c_double(v_minInOptional) if v_minInOptional != None else None, c_double(v_maxInOptional) if v_maxInOptional != None else None, rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = DragDouble4.func(args[0], args[1], byref(args[2]), byref(args[3]), byref(args[4]), byref(args[5]), byref(args[6]) if args[6] != None else None, byref(args[7]) if args[7] != None else None, byref(args[8]) if args[8] != None else None, args[9], byref(args[10]) if args[10] != None else None)
  return rval, float(args[2].value), float(args[3].value), float(args[4].value), float(args[5].value)

def DragDoubleN(ctx, label, values, speedInOptional = None, minInOptional = None, maxInOptional = None, formatInOptional = None, flagsInOptional = None):
  if not hasattr(DragDoubleN, 'func'):
    proc = rpr_getfp('ImGui_DragDoubleN')
    DragDoubleN.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_void_p(values), c_double(speedInOptional) if speedInOptional != None else None, c_double(minInOptional) if minInOptional != None else None, c_double(maxInOptional) if maxInOptional != None else None, rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = DragDoubleN.func(args[0], args[1], args[2], byref(args[3]) if args[3] != None else None, byref(args[4]) if args[4] != None else None, byref(args[5]) if args[5] != None else None, args[6], byref(args[7]) if args[7] != None else None)
  return rval

def DragFloatRange2(ctx, label, v_current_minInOut, v_current_maxInOut, v_speedInOptional = None, v_minInOptional = None, v_maxInOptional = None, formatInOptional = None, format_maxInOptional = None, flagsInOptional = None):
  if not hasattr(DragFloatRange2, 'func'):
    proc = rpr_getfp('ImGui_DragFloatRange2')
    DragFloatRange2.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_char_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_double(v_current_minInOut), c_double(v_current_maxInOut), c_double(v_speedInOptional) if v_speedInOptional != None else None, c_double(v_minInOptional) if v_minInOptional != None else None, c_double(v_maxInOptional) if v_maxInOptional != None else None, rpr_packsc(formatInOptional) if formatInOptional != None else None, rpr_packsc(format_maxInOptional) if format_maxInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = DragFloatRange2.func(args[0], args[1], byref(args[2]), byref(args[3]), byref(args[4]) if args[4] != None else None, byref(args[5]) if args[5] != None else None, byref(args[6]) if args[6] != None else None, args[7], args[8], byref(args[9]) if args[9] != None else None)
  return rval, float(args[2].value), float(args[3].value)

def DragInt(ctx, label, vInOut, v_speedInOptional = None, v_minInOptional = None, v_maxInOptional = None, formatInOptional = None, flagsInOptional = None):
  if not hasattr(DragInt, 'func'):
    proc = rpr_getfp('ImGui_DragInt')
    DragInt.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(vInOut), c_double(v_speedInOptional) if v_speedInOptional != None else None, c_int(v_minInOptional) if v_minInOptional != None else None, c_int(v_maxInOptional) if v_maxInOptional != None else None, rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = DragInt.func(args[0], args[1], byref(args[2]), byref(args[3]) if args[3] != None else None, byref(args[4]) if args[4] != None else None, byref(args[5]) if args[5] != None else None, args[6], byref(args[7]) if args[7] != None else None)
  return rval, int(args[2].value)

def DragInt2(ctx, label, v1InOut, v2InOut, v_speedInOptional = None, v_minInOptional = None, v_maxInOptional = None, formatInOptional = None, flagsInOptional = None):
  if not hasattr(DragInt2, 'func'):
    proc = rpr_getfp('ImGui_DragInt2')
    DragInt2.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(v1InOut), c_int(v2InOut), c_double(v_speedInOptional) if v_speedInOptional != None else None, c_int(v_minInOptional) if v_minInOptional != None else None, c_int(v_maxInOptional) if v_maxInOptional != None else None, rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = DragInt2.func(args[0], args[1], byref(args[2]), byref(args[3]), byref(args[4]) if args[4] != None else None, byref(args[5]) if args[5] != None else None, byref(args[6]) if args[6] != None else None, args[7], byref(args[8]) if args[8] != None else None)
  return rval, int(args[2].value), int(args[3].value)

def DragInt3(ctx, label, v1InOut, v2InOut, v3InOut, v_speedInOptional = None, v_minInOptional = None, v_maxInOptional = None, formatInOptional = None, flagsInOptional = None):
  if not hasattr(DragInt3, 'func'):
    proc = rpr_getfp('ImGui_DragInt3')
    DragInt3.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(v1InOut), c_int(v2InOut), c_int(v3InOut), c_double(v_speedInOptional) if v_speedInOptional != None else None, c_int(v_minInOptional) if v_minInOptional != None else None, c_int(v_maxInOptional) if v_maxInOptional != None else None, rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = DragInt3.func(args[0], args[1], byref(args[2]), byref(args[3]), byref(args[4]), byref(args[5]) if args[5] != None else None, byref(args[6]) if args[6] != None else None, byref(args[7]) if args[7] != None else None, args[8], byref(args[9]) if args[9] != None else None)
  return rval, int(args[2].value), int(args[3].value), int(args[4].value)

def DragInt4(ctx, label, v1InOut, v2InOut, v3InOut, v4InOut, v_speedInOptional = None, v_minInOptional = None, v_maxInOptional = None, formatInOptional = None, flagsInOptional = None):
  if not hasattr(DragInt4, 'func'):
    proc = rpr_getfp('ImGui_DragInt4')
    DragInt4.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(v1InOut), c_int(v2InOut), c_int(v3InOut), c_int(v4InOut), c_double(v_speedInOptional) if v_speedInOptional != None else None, c_int(v_minInOptional) if v_minInOptional != None else None, c_int(v_maxInOptional) if v_maxInOptional != None else None, rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = DragInt4.func(args[0], args[1], byref(args[2]), byref(args[3]), byref(args[4]), byref(args[5]), byref(args[6]) if args[6] != None else None, byref(args[7]) if args[7] != None else None, byref(args[8]) if args[8] != None else None, args[9], byref(args[10]) if args[10] != None else None)
  return rval, int(args[2].value), int(args[3].value), int(args[4].value), int(args[5].value)

def DragIntRange2(ctx, label, v_current_minInOut, v_current_maxInOut, v_speedInOptional = None, v_minInOptional = None, v_maxInOptional = None, formatInOptional = None, format_maxInOptional = None, flagsInOptional = None):
  if not hasattr(DragIntRange2, 'func'):
    proc = rpr_getfp('ImGui_DragIntRange2')
    DragIntRange2.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_char_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(v_current_minInOut), c_int(v_current_maxInOut), c_double(v_speedInOptional) if v_speedInOptional != None else None, c_int(v_minInOptional) if v_minInOptional != None else None, c_int(v_maxInOptional) if v_maxInOptional != None else None, rpr_packsc(formatInOptional) if formatInOptional != None else None, rpr_packsc(format_maxInOptional) if format_maxInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = DragIntRange2.func(args[0], args[1], byref(args[2]), byref(args[3]), byref(args[4]) if args[4] != None else None, byref(args[5]) if args[5] != None else None, byref(args[6]) if args[6] != None else None, args[7], args[8], byref(args[9]) if args[9] != None else None)
  return rval, int(args[2].value), int(args[3].value)

def SliderFlags_AlwaysClamp():
  if not hasattr(SliderFlags_AlwaysClamp, 'func'):
    proc = rpr_getfp('ImGui_SliderFlags_AlwaysClamp')
    SliderFlags_AlwaysClamp.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(SliderFlags_AlwaysClamp, 'cache'):
    SliderFlags_AlwaysClamp.cache = SliderFlags_AlwaysClamp.func()
  return SliderFlags_AlwaysClamp.cache

def SliderFlags_ClampOnInput():
  if not hasattr(SliderFlags_ClampOnInput, 'func'):
    proc = rpr_getfp('ImGui_SliderFlags_ClampOnInput')
    SliderFlags_ClampOnInput.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(SliderFlags_ClampOnInput, 'cache'):
    SliderFlags_ClampOnInput.cache = SliderFlags_ClampOnInput.func()
  return SliderFlags_ClampOnInput.cache

def SliderFlags_ClampZeroRange():
  if not hasattr(SliderFlags_ClampZeroRange, 'func'):
    proc = rpr_getfp('ImGui_SliderFlags_ClampZeroRange')
    SliderFlags_ClampZeroRange.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(SliderFlags_ClampZeroRange, 'cache'):
    SliderFlags_ClampZeroRange.cache = SliderFlags_ClampZeroRange.func()
  return SliderFlags_ClampZeroRange.cache

def SliderFlags_Logarithmic():
  if not hasattr(SliderFlags_Logarithmic, 'func'):
    proc = rpr_getfp('ImGui_SliderFlags_Logarithmic')
    SliderFlags_Logarithmic.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(SliderFlags_Logarithmic, 'cache'):
    SliderFlags_Logarithmic.cache = SliderFlags_Logarithmic.func()
  return SliderFlags_Logarithmic.cache

def SliderFlags_NoInput():
  if not hasattr(SliderFlags_NoInput, 'func'):
    proc = rpr_getfp('ImGui_SliderFlags_NoInput')
    SliderFlags_NoInput.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(SliderFlags_NoInput, 'cache'):
    SliderFlags_NoInput.cache = SliderFlags_NoInput.func()
  return SliderFlags_NoInput.cache

def SliderFlags_NoRoundToFormat():
  if not hasattr(SliderFlags_NoRoundToFormat, 'func'):
    proc = rpr_getfp('ImGui_SliderFlags_NoRoundToFormat')
    SliderFlags_NoRoundToFormat.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(SliderFlags_NoRoundToFormat, 'cache'):
    SliderFlags_NoRoundToFormat.cache = SliderFlags_NoRoundToFormat.func()
  return SliderFlags_NoRoundToFormat.cache

def SliderFlags_NoSpeedTweaks():
  if not hasattr(SliderFlags_NoSpeedTweaks, 'func'):
    proc = rpr_getfp('ImGui_SliderFlags_NoSpeedTweaks')
    SliderFlags_NoSpeedTweaks.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(SliderFlags_NoSpeedTweaks, 'cache'):
    SliderFlags_NoSpeedTweaks.cache = SliderFlags_NoSpeedTweaks.func()
  return SliderFlags_NoSpeedTweaks.cache

def SliderFlags_None():
  if not hasattr(SliderFlags_None, 'func'):
    proc = rpr_getfp('ImGui_SliderFlags_None')
    SliderFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(SliderFlags_None, 'cache'):
    SliderFlags_None.cache = SliderFlags_None.func()
  return SliderFlags_None.cache

def SliderFlags_WrapAround():
  if not hasattr(SliderFlags_WrapAround, 'func'):
    proc = rpr_getfp('ImGui_SliderFlags_WrapAround')
    SliderFlags_WrapAround.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(SliderFlags_WrapAround, 'cache'):
    SliderFlags_WrapAround.cache = SliderFlags_WrapAround.func()
  return SliderFlags_WrapAround.cache

def SliderAngle(ctx, label, v_radInOut, v_degrees_minInOptional = None, v_degrees_maxInOptional = None, formatInOptional = None, flagsInOptional = None):
  if not hasattr(SliderAngle, 'func'):
    proc = rpr_getfp('ImGui_SliderAngle')
    SliderAngle.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_double(v_radInOut), c_double(v_degrees_minInOptional) if v_degrees_minInOptional != None else None, c_double(v_degrees_maxInOptional) if v_degrees_maxInOptional != None else None, rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = SliderAngle.func(args[0], args[1], byref(args[2]), byref(args[3]) if args[3] != None else None, byref(args[4]) if args[4] != None else None, args[5], byref(args[6]) if args[6] != None else None)
  return rval, float(args[2].value)

def SliderDouble(ctx, label, vInOut, v_min, v_max, formatInOptional = None, flagsInOptional = None):
  if not hasattr(SliderDouble, 'func'):
    proc = rpr_getfp('ImGui_SliderDouble')
    SliderDouble.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_double, c_double, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_double(vInOut), c_double(v_min), c_double(v_max), rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = SliderDouble.func(args[0], args[1], byref(args[2]), args[3], args[4], args[5], byref(args[6]) if args[6] != None else None)
  return rval, float(args[2].value)

def SliderDouble2(ctx, label, v1InOut, v2InOut, v_min, v_max, formatInOptional = None, flagsInOptional = None):
  if not hasattr(SliderDouble2, 'func'):
    proc = rpr_getfp('ImGui_SliderDouble2')
    SliderDouble2.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_double, c_double, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_double(v1InOut), c_double(v2InOut), c_double(v_min), c_double(v_max), rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = SliderDouble2.func(args[0], args[1], byref(args[2]), byref(args[3]), args[4], args[5], args[6], byref(args[7]) if args[7] != None else None)
  return rval, float(args[2].value), float(args[3].value)

def SliderDouble3(ctx, label, v1InOut, v2InOut, v3InOut, v_min, v_max, formatInOptional = None, flagsInOptional = None):
  if not hasattr(SliderDouble3, 'func'):
    proc = rpr_getfp('ImGui_SliderDouble3')
    SliderDouble3.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_double, c_double, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_double(v1InOut), c_double(v2InOut), c_double(v3InOut), c_double(v_min), c_double(v_max), rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = SliderDouble3.func(args[0], args[1], byref(args[2]), byref(args[3]), byref(args[4]), args[5], args[6], args[7], byref(args[8]) if args[8] != None else None)
  return rval, float(args[2].value), float(args[3].value), float(args[4].value)

def SliderDouble4(ctx, label, v1InOut, v2InOut, v3InOut, v4InOut, v_min, v_max, formatInOptional = None, flagsInOptional = None):
  if not hasattr(SliderDouble4, 'func'):
    proc = rpr_getfp('ImGui_SliderDouble4')
    SliderDouble4.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p, c_double, c_double, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_double(v1InOut), c_double(v2InOut), c_double(v3InOut), c_double(v4InOut), c_double(v_min), c_double(v_max), rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = SliderDouble4.func(args[0], args[1], byref(args[2]), byref(args[3]), byref(args[4]), byref(args[5]), args[6], args[7], args[8], byref(args[9]) if args[9] != None else None)
  return rval, float(args[2].value), float(args[3].value), float(args[4].value), float(args[5].value)

def SliderDoubleN(ctx, label, values, v_min, v_max, formatInOptional = None, flagsInOptional = None):
  if not hasattr(SliderDoubleN, 'func'):
    proc = rpr_getfp('ImGui_SliderDoubleN')
    SliderDoubleN.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_double, c_double, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_void_p(values), c_double(v_min), c_double(v_max), rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = SliderDoubleN.func(args[0], args[1], args[2], args[3], args[4], args[5], byref(args[6]) if args[6] != None else None)
  return rval

def SliderInt(ctx, label, vInOut, v_min, v_max, formatInOptional = None, flagsInOptional = None):
  if not hasattr(SliderInt, 'func'):
    proc = rpr_getfp('ImGui_SliderInt')
    SliderInt.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_int, c_int, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(vInOut), c_int(v_min), c_int(v_max), rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = SliderInt.func(args[0], args[1], byref(args[2]), args[3], args[4], args[5], byref(args[6]) if args[6] != None else None)
  return rval, int(args[2].value)

def SliderInt2(ctx, label, v1InOut, v2InOut, v_min, v_max, formatInOptional = None, flagsInOptional = None):
  if not hasattr(SliderInt2, 'func'):
    proc = rpr_getfp('ImGui_SliderInt2')
    SliderInt2.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_int, c_int, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(v1InOut), c_int(v2InOut), c_int(v_min), c_int(v_max), rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = SliderInt2.func(args[0], args[1], byref(args[2]), byref(args[3]), args[4], args[5], args[6], byref(args[7]) if args[7] != None else None)
  return rval, int(args[2].value), int(args[3].value)

def SliderInt3(ctx, label, v1InOut, v2InOut, v3InOut, v_min, v_max, formatInOptional = None, flagsInOptional = None):
  if not hasattr(SliderInt3, 'func'):
    proc = rpr_getfp('ImGui_SliderInt3')
    SliderInt3.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_int, c_int, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(v1InOut), c_int(v2InOut), c_int(v3InOut), c_int(v_min), c_int(v_max), rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = SliderInt3.func(args[0], args[1], byref(args[2]), byref(args[3]), byref(args[4]), args[5], args[6], args[7], byref(args[8]) if args[8] != None else None)
  return rval, int(args[2].value), int(args[3].value), int(args[4].value)

def SliderInt4(ctx, label, v1InOut, v2InOut, v3InOut, v4InOut, v_min, v_max, formatInOptional = None, flagsInOptional = None):
  if not hasattr(SliderInt4, 'func'):
    proc = rpr_getfp('ImGui_SliderInt4')
    SliderInt4.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p, c_int, c_int, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(v1InOut), c_int(v2InOut), c_int(v3InOut), c_int(v4InOut), c_int(v_min), c_int(v_max), rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = SliderInt4.func(args[0], args[1], byref(args[2]), byref(args[3]), byref(args[4]), byref(args[5]), args[6], args[7], args[8], byref(args[9]) if args[9] != None else None)
  return rval, int(args[2].value), int(args[3].value), int(args[4].value), int(args[5].value)

def VSliderDouble(ctx, label, size_w, size_h, vInOut, v_min, v_max, formatInOptional = None, flagsInOptional = None):
  if not hasattr(VSliderDouble, 'func'):
    proc = rpr_getfp('ImGui_VSliderDouble')
    VSliderDouble.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_double, c_double, c_void_p, c_double, c_double, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_double(size_w), c_double(size_h), c_double(vInOut), c_double(v_min), c_double(v_max), rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = VSliderDouble.func(args[0], args[1], args[2], args[3], byref(args[4]), args[5], args[6], args[7], byref(args[8]) if args[8] != None else None)
  return rval, float(args[4].value)

def VSliderInt(ctx, label, size_w, size_h, vInOut, v_min, v_max, formatInOptional = None, flagsInOptional = None):
  if not hasattr(VSliderInt, 'func'):
    proc = rpr_getfp('ImGui_VSliderInt')
    VSliderInt.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_double, c_double, c_void_p, c_int, c_int, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_double(size_w), c_double(size_h), c_int(vInOut), c_int(v_min), c_int(v_max), rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = VSliderInt.func(args[0], args[1], args[2], args[3], byref(args[4]), args[5], args[6], args[7], byref(args[8]) if args[8] != None else None)
  return rval, int(args[4].value)

def DrawFlags_Closed():
  if not hasattr(DrawFlags_Closed, 'func'):
    proc = rpr_getfp('ImGui_DrawFlags_Closed')
    DrawFlags_Closed.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DrawFlags_Closed, 'cache'):
    DrawFlags_Closed.cache = DrawFlags_Closed.func()
  return DrawFlags_Closed.cache

def DrawFlags_None():
  if not hasattr(DrawFlags_None, 'func'):
    proc = rpr_getfp('ImGui_DrawFlags_None')
    DrawFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DrawFlags_None, 'cache'):
    DrawFlags_None.cache = DrawFlags_None.func()
  return DrawFlags_None.cache

def DrawFlags_RoundCornersAll():
  if not hasattr(DrawFlags_RoundCornersAll, 'func'):
    proc = rpr_getfp('ImGui_DrawFlags_RoundCornersAll')
    DrawFlags_RoundCornersAll.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DrawFlags_RoundCornersAll, 'cache'):
    DrawFlags_RoundCornersAll.cache = DrawFlags_RoundCornersAll.func()
  return DrawFlags_RoundCornersAll.cache

def DrawFlags_RoundCornersBottom():
  if not hasattr(DrawFlags_RoundCornersBottom, 'func'):
    proc = rpr_getfp('ImGui_DrawFlags_RoundCornersBottom')
    DrawFlags_RoundCornersBottom.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DrawFlags_RoundCornersBottom, 'cache'):
    DrawFlags_RoundCornersBottom.cache = DrawFlags_RoundCornersBottom.func()
  return DrawFlags_RoundCornersBottom.cache

def DrawFlags_RoundCornersBottomLeft():
  if not hasattr(DrawFlags_RoundCornersBottomLeft, 'func'):
    proc = rpr_getfp('ImGui_DrawFlags_RoundCornersBottomLeft')
    DrawFlags_RoundCornersBottomLeft.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DrawFlags_RoundCornersBottomLeft, 'cache'):
    DrawFlags_RoundCornersBottomLeft.cache = DrawFlags_RoundCornersBottomLeft.func()
  return DrawFlags_RoundCornersBottomLeft.cache

def DrawFlags_RoundCornersBottomRight():
  if not hasattr(DrawFlags_RoundCornersBottomRight, 'func'):
    proc = rpr_getfp('ImGui_DrawFlags_RoundCornersBottomRight')
    DrawFlags_RoundCornersBottomRight.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DrawFlags_RoundCornersBottomRight, 'cache'):
    DrawFlags_RoundCornersBottomRight.cache = DrawFlags_RoundCornersBottomRight.func()
  return DrawFlags_RoundCornersBottomRight.cache

def DrawFlags_RoundCornersLeft():
  if not hasattr(DrawFlags_RoundCornersLeft, 'func'):
    proc = rpr_getfp('ImGui_DrawFlags_RoundCornersLeft')
    DrawFlags_RoundCornersLeft.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DrawFlags_RoundCornersLeft, 'cache'):
    DrawFlags_RoundCornersLeft.cache = DrawFlags_RoundCornersLeft.func()
  return DrawFlags_RoundCornersLeft.cache

def DrawFlags_RoundCornersNone():
  if not hasattr(DrawFlags_RoundCornersNone, 'func'):
    proc = rpr_getfp('ImGui_DrawFlags_RoundCornersNone')
    DrawFlags_RoundCornersNone.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DrawFlags_RoundCornersNone, 'cache'):
    DrawFlags_RoundCornersNone.cache = DrawFlags_RoundCornersNone.func()
  return DrawFlags_RoundCornersNone.cache

def DrawFlags_RoundCornersRight():
  if not hasattr(DrawFlags_RoundCornersRight, 'func'):
    proc = rpr_getfp('ImGui_DrawFlags_RoundCornersRight')
    DrawFlags_RoundCornersRight.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DrawFlags_RoundCornersRight, 'cache'):
    DrawFlags_RoundCornersRight.cache = DrawFlags_RoundCornersRight.func()
  return DrawFlags_RoundCornersRight.cache

def DrawFlags_RoundCornersTop():
  if not hasattr(DrawFlags_RoundCornersTop, 'func'):
    proc = rpr_getfp('ImGui_DrawFlags_RoundCornersTop')
    DrawFlags_RoundCornersTop.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DrawFlags_RoundCornersTop, 'cache'):
    DrawFlags_RoundCornersTop.cache = DrawFlags_RoundCornersTop.func()
  return DrawFlags_RoundCornersTop.cache

def DrawFlags_RoundCornersTopLeft():
  if not hasattr(DrawFlags_RoundCornersTopLeft, 'func'):
    proc = rpr_getfp('ImGui_DrawFlags_RoundCornersTopLeft')
    DrawFlags_RoundCornersTopLeft.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DrawFlags_RoundCornersTopLeft, 'cache'):
    DrawFlags_RoundCornersTopLeft.cache = DrawFlags_RoundCornersTopLeft.func()
  return DrawFlags_RoundCornersTopLeft.cache

def DrawFlags_RoundCornersTopRight():
  if not hasattr(DrawFlags_RoundCornersTopRight, 'func'):
    proc = rpr_getfp('ImGui_DrawFlags_RoundCornersTopRight')
    DrawFlags_RoundCornersTopRight.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(DrawFlags_RoundCornersTopRight, 'cache'):
    DrawFlags_RoundCornersTopRight.cache = DrawFlags_RoundCornersTopRight.func()
  return DrawFlags_RoundCornersTopRight.cache

def DrawList_PopClipRect(draw_list):
  if not hasattr(DrawList_PopClipRect, 'func'):
    proc = rpr_getfp('ImGui_DrawList_PopClipRect')
    DrawList_PopClipRect.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(draw_list),)
  DrawList_PopClipRect.func(args[0])

def DrawList_PushClipRect(draw_list, clip_rect_min_x, clip_rect_min_y, clip_rect_max_x, clip_rect_max_y, intersect_with_current_clip_rectInOptional = None):
  if not hasattr(DrawList_PushClipRect, 'func'):
    proc = rpr_getfp('ImGui_DrawList_PushClipRect')
    DrawList_PushClipRect.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_double, c_void_p)(proc)
  args = (c_void_p(draw_list), c_double(clip_rect_min_x), c_double(clip_rect_min_y), c_double(clip_rect_max_x), c_double(clip_rect_max_y), c_bool(intersect_with_current_clip_rectInOptional) if intersect_with_current_clip_rectInOptional != None else None)
  DrawList_PushClipRect.func(args[0], args[1], args[2], args[3], args[4], byref(args[5]) if args[5] != None else None)

def DrawList_PushClipRectFullScreen(draw_list):
  if not hasattr(DrawList_PushClipRectFullScreen, 'func'):
    proc = rpr_getfp('ImGui_DrawList_PushClipRectFullScreen')
    DrawList_PushClipRectFullScreen.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(draw_list),)
  DrawList_PushClipRectFullScreen.func(args[0])

def GetBackgroundDrawList(ctx):
  if not hasattr(GetBackgroundDrawList, 'func'):
    proc = rpr_getfp('ImGui_GetBackgroundDrawList')
    GetBackgroundDrawList.func = CFUNCTYPE(c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetBackgroundDrawList.func(args[0])
  return rval

def GetForegroundDrawList(ctx):
  if not hasattr(GetForegroundDrawList, 'func'):
    proc = rpr_getfp('ImGui_GetForegroundDrawList')
    GetForegroundDrawList.func = CFUNCTYPE(c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetForegroundDrawList.func(args[0])
  return rval

def GetWindowDrawList(ctx):
  if not hasattr(GetWindowDrawList, 'func'):
    proc = rpr_getfp('ImGui_GetWindowDrawList')
    GetWindowDrawList.func = CFUNCTYPE(c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetWindowDrawList.func(args[0])
  return rval

def DrawList_AddBezierCubic(draw_list, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, col_rgba, thickness, num_segmentsInOptional = None):
  if not hasattr(DrawList_AddBezierCubic, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddBezierCubic')
    DrawList_AddBezierCubic.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_double, c_double, c_double, c_double, c_double, c_int, c_double, c_void_p)(proc)
  args = (c_void_p(draw_list), c_double(p1_x), c_double(p1_y), c_double(p2_x), c_double(p2_y), c_double(p3_x), c_double(p3_y), c_double(p4_x), c_double(p4_y), c_int(col_rgba), c_double(thickness), c_int(num_segmentsInOptional) if num_segmentsInOptional != None else None)
  DrawList_AddBezierCubic.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], byref(args[11]) if args[11] != None else None)

def DrawList_AddBezierQuadratic(draw_list, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, col_rgba, thickness, num_segmentsInOptional = None):
  if not hasattr(DrawList_AddBezierQuadratic, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddBezierQuadratic')
    DrawList_AddBezierQuadratic.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_double, c_double, c_double, c_int, c_double, c_void_p)(proc)
  args = (c_void_p(draw_list), c_double(p1_x), c_double(p1_y), c_double(p2_x), c_double(p2_y), c_double(p3_x), c_double(p3_y), c_int(col_rgba), c_double(thickness), c_int(num_segmentsInOptional) if num_segmentsInOptional != None else None)
  DrawList_AddBezierQuadratic.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], byref(args[9]) if args[9] != None else None)

def DrawList_AddCircle(draw_list, center_x, center_y, radius, col_rgba, num_segmentsInOptional = None, thicknessInOptional = None):
  if not hasattr(DrawList_AddCircle, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddCircle')
    DrawList_AddCircle.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_int, c_void_p, c_void_p)(proc)
  args = (c_void_p(draw_list), c_double(center_x), c_double(center_y), c_double(radius), c_int(col_rgba), c_int(num_segmentsInOptional) if num_segmentsInOptional != None else None, c_double(thicknessInOptional) if thicknessInOptional != None else None)
  DrawList_AddCircle.func(args[0], args[1], args[2], args[3], args[4], byref(args[5]) if args[5] != None else None, byref(args[6]) if args[6] != None else None)

def DrawList_AddCircleFilled(draw_list, center_x, center_y, radius, col_rgba, num_segmentsInOptional = None):
  if not hasattr(DrawList_AddCircleFilled, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddCircleFilled')
    DrawList_AddCircleFilled.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_int, c_void_p)(proc)
  args = (c_void_p(draw_list), c_double(center_x), c_double(center_y), c_double(radius), c_int(col_rgba), c_int(num_segmentsInOptional) if num_segmentsInOptional != None else None)
  DrawList_AddCircleFilled.func(args[0], args[1], args[2], args[3], args[4], byref(args[5]) if args[5] != None else None)

def DrawList_AddConcavePolyFilled(draw_list, points, col_rgba):
  if not hasattr(DrawList_AddConcavePolyFilled, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddConcavePolyFilled')
    DrawList_AddConcavePolyFilled.func = CFUNCTYPE(None, c_void_p, c_void_p, c_int)(proc)
  args = (c_void_p(draw_list), c_void_p(points), c_int(col_rgba))
  DrawList_AddConcavePolyFilled.func(args[0], args[1], args[2])

def DrawList_AddConvexPolyFilled(draw_list, points, col_rgba):
  if not hasattr(DrawList_AddConvexPolyFilled, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddConvexPolyFilled')
    DrawList_AddConvexPolyFilled.func = CFUNCTYPE(None, c_void_p, c_void_p, c_int)(proc)
  args = (c_void_p(draw_list), c_void_p(points), c_int(col_rgba))
  DrawList_AddConvexPolyFilled.func(args[0], args[1], args[2])

def DrawList_AddEllipse(draw_list, center_x, center_y, radius_x, radius_y, col_rgba, rotInOptional = None, num_segmentsInOptional = None, thicknessInOptional = None):
  if not hasattr(DrawList_AddEllipse, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddEllipse')
    DrawList_AddEllipse.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_double, c_int, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(draw_list), c_double(center_x), c_double(center_y), c_double(radius_x), c_double(radius_y), c_int(col_rgba), c_double(rotInOptional) if rotInOptional != None else None, c_int(num_segmentsInOptional) if num_segmentsInOptional != None else None, c_double(thicknessInOptional) if thicknessInOptional != None else None)
  DrawList_AddEllipse.func(args[0], args[1], args[2], args[3], args[4], args[5], byref(args[6]) if args[6] != None else None, byref(args[7]) if args[7] != None else None, byref(args[8]) if args[8] != None else None)

def DrawList_AddEllipseFilled(draw_list, center_x, center_y, radius_x, radius_y, col_rgba, rotInOptional = None, num_segmentsInOptional = None):
  if not hasattr(DrawList_AddEllipseFilled, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddEllipseFilled')
    DrawList_AddEllipseFilled.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_double, c_int, c_void_p, c_void_p)(proc)
  args = (c_void_p(draw_list), c_double(center_x), c_double(center_y), c_double(radius_x), c_double(radius_y), c_int(col_rgba), c_double(rotInOptional) if rotInOptional != None else None, c_int(num_segmentsInOptional) if num_segmentsInOptional != None else None)
  DrawList_AddEllipseFilled.func(args[0], args[1], args[2], args[3], args[4], args[5], byref(args[6]) if args[6] != None else None, byref(args[7]) if args[7] != None else None)

def DrawList_AddImage(draw_list, image, p_min_x, p_min_y, p_max_x, p_max_y, uv_min_xInOptional = None, uv_min_yInOptional = None, uv_max_xInOptional = None, uv_max_yInOptional = None, col_rgbaInOptional = None):
  if not hasattr(DrawList_AddImage, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddImage')
    DrawList_AddImage.func = CFUNCTYPE(None, c_void_p, c_void_p, c_double, c_double, c_double, c_double, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(draw_list), c_void_p(image), c_double(p_min_x), c_double(p_min_y), c_double(p_max_x), c_double(p_max_y), c_double(uv_min_xInOptional) if uv_min_xInOptional != None else None, c_double(uv_min_yInOptional) if uv_min_yInOptional != None else None, c_double(uv_max_xInOptional) if uv_max_xInOptional != None else None, c_double(uv_max_yInOptional) if uv_max_yInOptional != None else None, c_int(col_rgbaInOptional) if col_rgbaInOptional != None else None)
  DrawList_AddImage.func(args[0], args[1], args[2], args[3], args[4], args[5], byref(args[6]) if args[6] != None else None, byref(args[7]) if args[7] != None else None, byref(args[8]) if args[8] != None else None, byref(args[9]) if args[9] != None else None, byref(args[10]) if args[10] != None else None)

def DrawList_AddImageQuad(draw_list, image, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, uv1_xInOptional = None, uv1_yInOptional = None, uv2_xInOptional = None, uv2_yInOptional = None, uv3_xInOptional = None, uv3_yInOptional = None, uv4_xInOptional = None, uv4_yInOptional = None, col_rgbaInOptional = None):
  if not hasattr(DrawList_AddImageQuad, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddImageQuad')
    DrawList_AddImageQuad.func = CFUNCTYPE(None, c_void_p, c_void_p, c_double, c_double, c_double, c_double, c_double, c_double, c_double, c_double, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(draw_list), c_void_p(image), c_double(p1_x), c_double(p1_y), c_double(p2_x), c_double(p2_y), c_double(p3_x), c_double(p3_y), c_double(p4_x), c_double(p4_y), c_double(uv1_xInOptional) if uv1_xInOptional != None else None, c_double(uv1_yInOptional) if uv1_yInOptional != None else None, c_double(uv2_xInOptional) if uv2_xInOptional != None else None, c_double(uv2_yInOptional) if uv2_yInOptional != None else None, c_double(uv3_xInOptional) if uv3_xInOptional != None else None, c_double(uv3_yInOptional) if uv3_yInOptional != None else None, c_double(uv4_xInOptional) if uv4_xInOptional != None else None, c_double(uv4_yInOptional) if uv4_yInOptional != None else None, c_int(col_rgbaInOptional) if col_rgbaInOptional != None else None)
  DrawList_AddImageQuad.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], byref(args[10]) if args[10] != None else None, byref(args[11]) if args[11] != None else None, byref(args[12]) if args[12] != None else None, byref(args[13]) if args[13] != None else None, byref(args[14]) if args[14] != None else None, byref(args[15]) if args[15] != None else None, byref(args[16]) if args[16] != None else None, byref(args[17]) if args[17] != None else None, byref(args[18]) if args[18] != None else None)

def DrawList_AddImageRounded(draw_list, image, p_min_x, p_min_y, p_max_x, p_max_y, uv_min_x, uv_min_y, uv_max_x, uv_max_y, col_rgba, rounding, flagsInOptional = None):
  if not hasattr(DrawList_AddImageRounded, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddImageRounded')
    DrawList_AddImageRounded.func = CFUNCTYPE(None, c_void_p, c_void_p, c_double, c_double, c_double, c_double, c_double, c_double, c_double, c_double, c_int, c_double, c_void_p)(proc)
  args = (c_void_p(draw_list), c_void_p(image), c_double(p_min_x), c_double(p_min_y), c_double(p_max_x), c_double(p_max_y), c_double(uv_min_x), c_double(uv_min_y), c_double(uv_max_x), c_double(uv_max_y), c_int(col_rgba), c_double(rounding), c_int(flagsInOptional) if flagsInOptional != None else None)
  DrawList_AddImageRounded.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], args[10], args[11], byref(args[12]) if args[12] != None else None)

def DrawList_AddLine(draw_list, p1_x, p1_y, p2_x, p2_y, col_rgba, thicknessInOptional = None):
  if not hasattr(DrawList_AddLine, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddLine')
    DrawList_AddLine.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_double, c_int, c_void_p)(proc)
  args = (c_void_p(draw_list), c_double(p1_x), c_double(p1_y), c_double(p2_x), c_double(p2_y), c_int(col_rgba), c_double(thicknessInOptional) if thicknessInOptional != None else None)
  DrawList_AddLine.func(args[0], args[1], args[2], args[3], args[4], args[5], byref(args[6]) if args[6] != None else None)

def DrawList_AddNgon(draw_list, center_x, center_y, radius, col_rgba, num_segments, thicknessInOptional = None):
  if not hasattr(DrawList_AddNgon, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddNgon')
    DrawList_AddNgon.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_int, c_int, c_void_p)(proc)
  args = (c_void_p(draw_list), c_double(center_x), c_double(center_y), c_double(radius), c_int(col_rgba), c_int(num_segments), c_double(thicknessInOptional) if thicknessInOptional != None else None)
  DrawList_AddNgon.func(args[0], args[1], args[2], args[3], args[4], args[5], byref(args[6]) if args[6] != None else None)

def DrawList_AddNgonFilled(draw_list, center_x, center_y, radius, col_rgba, num_segments):
  if not hasattr(DrawList_AddNgonFilled, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddNgonFilled')
    DrawList_AddNgonFilled.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_int, c_int)(proc)
  args = (c_void_p(draw_list), c_double(center_x), c_double(center_y), c_double(radius), c_int(col_rgba), c_int(num_segments))
  DrawList_AddNgonFilled.func(args[0], args[1], args[2], args[3], args[4], args[5])

def DrawList_AddPolyline(draw_list, points, col_rgba, flags, thickness):
  if not hasattr(DrawList_AddPolyline, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddPolyline')
    DrawList_AddPolyline.func = CFUNCTYPE(None, c_void_p, c_void_p, c_int, c_int, c_double)(proc)
  args = (c_void_p(draw_list), c_void_p(points), c_int(col_rgba), c_int(flags), c_double(thickness))
  DrawList_AddPolyline.func(args[0], args[1], args[2], args[3], args[4])

def DrawList_AddQuad(draw_list, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, col_rgba, thicknessInOptional = None):
  if not hasattr(DrawList_AddQuad, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddQuad')
    DrawList_AddQuad.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_double, c_double, c_double, c_double, c_double, c_int, c_void_p)(proc)
  args = (c_void_p(draw_list), c_double(p1_x), c_double(p1_y), c_double(p2_x), c_double(p2_y), c_double(p3_x), c_double(p3_y), c_double(p4_x), c_double(p4_y), c_int(col_rgba), c_double(thicknessInOptional) if thicknessInOptional != None else None)
  DrawList_AddQuad.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9], byref(args[10]) if args[10] != None else None)

def DrawList_AddQuadFilled(draw_list, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, col_rgba):
  if not hasattr(DrawList_AddQuadFilled, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddQuadFilled')
    DrawList_AddQuadFilled.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_double, c_double, c_double, c_double, c_double, c_int)(proc)
  args = (c_void_p(draw_list), c_double(p1_x), c_double(p1_y), c_double(p2_x), c_double(p2_y), c_double(p3_x), c_double(p3_y), c_double(p4_x), c_double(p4_y), c_int(col_rgba))
  DrawList_AddQuadFilled.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9])

def DrawList_AddRect(draw_list, p_min_x, p_min_y, p_max_x, p_max_y, col_rgba, roundingInOptional = None, flagsInOptional = None, thicknessInOptional = None):
  if not hasattr(DrawList_AddRect, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddRect')
    DrawList_AddRect.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_double, c_int, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(draw_list), c_double(p_min_x), c_double(p_min_y), c_double(p_max_x), c_double(p_max_y), c_int(col_rgba), c_double(roundingInOptional) if roundingInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None, c_double(thicknessInOptional) if thicknessInOptional != None else None)
  DrawList_AddRect.func(args[0], args[1], args[2], args[3], args[4], args[5], byref(args[6]) if args[6] != None else None, byref(args[7]) if args[7] != None else None, byref(args[8]) if args[8] != None else None)

def DrawList_AddRectFilled(draw_list, p_min_x, p_min_y, p_max_x, p_max_y, col_rgba, roundingInOptional = None, flagsInOptional = None):
  if not hasattr(DrawList_AddRectFilled, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddRectFilled')
    DrawList_AddRectFilled.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_double, c_int, c_void_p, c_void_p)(proc)
  args = (c_void_p(draw_list), c_double(p_min_x), c_double(p_min_y), c_double(p_max_x), c_double(p_max_y), c_int(col_rgba), c_double(roundingInOptional) if roundingInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  DrawList_AddRectFilled.func(args[0], args[1], args[2], args[3], args[4], args[5], byref(args[6]) if args[6] != None else None, byref(args[7]) if args[7] != None else None)

def DrawList_AddRectFilledMultiColor(draw_list, p_min_x, p_min_y, p_max_x, p_max_y, col_upr_left, col_upr_right, col_bot_right, col_bot_left):
  if not hasattr(DrawList_AddRectFilledMultiColor, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddRectFilledMultiColor')
    DrawList_AddRectFilledMultiColor.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_double, c_int, c_int, c_int, c_int)(proc)
  args = (c_void_p(draw_list), c_double(p_min_x), c_double(p_min_y), c_double(p_max_x), c_double(p_max_y), c_int(col_upr_left), c_int(col_upr_right), c_int(col_bot_right), c_int(col_bot_left))
  DrawList_AddRectFilledMultiColor.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8])

def DrawList_AddText(draw_list, x, y, col_rgba, text):
  if not hasattr(DrawList_AddText, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddText')
    DrawList_AddText.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_int, c_char_p)(proc)
  args = (c_void_p(draw_list), c_double(x), c_double(y), c_int(col_rgba), rpr_packsc(text))
  DrawList_AddText.func(args[0], args[1], args[2], args[3], args[4])

def DrawList_AddTextEx(draw_list, font, font_size, pos_x, pos_y, col_rgba, text, wrap_widthInOptional = None, cpu_fine_clip_rect_min_xInOptional = None, cpu_fine_clip_rect_min_yInOptional = None, cpu_fine_clip_rect_max_xInOptional = None, cpu_fine_clip_rect_max_yInOptional = None):
  if not hasattr(DrawList_AddTextEx, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddTextEx')
    DrawList_AddTextEx.func = CFUNCTYPE(None, c_void_p, c_void_p, c_double, c_double, c_double, c_int, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(draw_list), c_void_p(font), c_double(font_size), c_double(pos_x), c_double(pos_y), c_int(col_rgba), rpr_packsc(text), c_double(wrap_widthInOptional) if wrap_widthInOptional != None else None, c_double(cpu_fine_clip_rect_min_xInOptional) if cpu_fine_clip_rect_min_xInOptional != None else None, c_double(cpu_fine_clip_rect_min_yInOptional) if cpu_fine_clip_rect_min_yInOptional != None else None, c_double(cpu_fine_clip_rect_max_xInOptional) if cpu_fine_clip_rect_max_xInOptional != None else None, c_double(cpu_fine_clip_rect_max_yInOptional) if cpu_fine_clip_rect_max_yInOptional != None else None)
  DrawList_AddTextEx.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], byref(args[7]) if args[7] != None else None, byref(args[8]) if args[8] != None else None, byref(args[9]) if args[9] != None else None, byref(args[10]) if args[10] != None else None, byref(args[11]) if args[11] != None else None)

def DrawList_AddTriangle(draw_list, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, col_rgba, thicknessInOptional = None):
  if not hasattr(DrawList_AddTriangle, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddTriangle')
    DrawList_AddTriangle.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_double, c_double, c_double, c_int, c_void_p)(proc)
  args = (c_void_p(draw_list), c_double(p1_x), c_double(p1_y), c_double(p2_x), c_double(p2_y), c_double(p3_x), c_double(p3_y), c_int(col_rgba), c_double(thicknessInOptional) if thicknessInOptional != None else None)
  DrawList_AddTriangle.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], byref(args[8]) if args[8] != None else None)

def DrawList_AddTriangleFilled(draw_list, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y, col_rgba):
  if not hasattr(DrawList_AddTriangleFilled, 'func'):
    proc = rpr_getfp('ImGui_DrawList_AddTriangleFilled')
    DrawList_AddTriangleFilled.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_double, c_double, c_double, c_int)(proc)
  args = (c_void_p(draw_list), c_double(p1_x), c_double(p1_y), c_double(p2_x), c_double(p2_y), c_double(p3_x), c_double(p3_y), c_int(col_rgba))
  DrawList_AddTriangleFilled.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7])

def CreateDrawListSplitter(draw_list):
  if not hasattr(CreateDrawListSplitter, 'func'):
    proc = rpr_getfp('ImGui_CreateDrawListSplitter')
    CreateDrawListSplitter.func = CFUNCTYPE(c_void_p, c_void_p)(proc)
  args = (c_void_p(draw_list),)
  rval = CreateDrawListSplitter.func(args[0])
  return rval

def DrawListSplitter_Clear(splitter):
  if not hasattr(DrawListSplitter_Clear, 'func'):
    proc = rpr_getfp('ImGui_DrawListSplitter_Clear')
    DrawListSplitter_Clear.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(splitter),)
  DrawListSplitter_Clear.func(args[0])

def DrawListSplitter_Merge(splitter):
  if not hasattr(DrawListSplitter_Merge, 'func'):
    proc = rpr_getfp('ImGui_DrawListSplitter_Merge')
    DrawListSplitter_Merge.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(splitter),)
  DrawListSplitter_Merge.func(args[0])

def DrawListSplitter_SetCurrentChannel(splitter, channel_idx):
  if not hasattr(DrawListSplitter_SetCurrentChannel, 'func'):
    proc = rpr_getfp('ImGui_DrawListSplitter_SetCurrentChannel')
    DrawListSplitter_SetCurrentChannel.func = CFUNCTYPE(None, c_void_p, c_int)(proc)
  args = (c_void_p(splitter), c_int(channel_idx))
  DrawListSplitter_SetCurrentChannel.func(args[0], args[1])

def DrawListSplitter_Split(splitter, count):
  if not hasattr(DrawListSplitter_Split, 'func'):
    proc = rpr_getfp('ImGui_DrawListSplitter_Split')
    DrawListSplitter_Split.func = CFUNCTYPE(None, c_void_p, c_int)(proc)
  args = (c_void_p(splitter), c_int(count))
  DrawListSplitter_Split.func(args[0], args[1])

def DrawList_PathArcTo(draw_list, center_x, center_y, radius, a_min, a_max, num_segmentsInOptional = None):
  if not hasattr(DrawList_PathArcTo, 'func'):
    proc = rpr_getfp('ImGui_DrawList_PathArcTo')
    DrawList_PathArcTo.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_double, c_double, c_void_p)(proc)
  args = (c_void_p(draw_list), c_double(center_x), c_double(center_y), c_double(radius), c_double(a_min), c_double(a_max), c_int(num_segmentsInOptional) if num_segmentsInOptional != None else None)
  DrawList_PathArcTo.func(args[0], args[1], args[2], args[3], args[4], args[5], byref(args[6]) if args[6] != None else None)

def DrawList_PathArcToFast(draw_list, center_x, center_y, radius, a_min_of_12, a_max_of_12):
  if not hasattr(DrawList_PathArcToFast, 'func'):
    proc = rpr_getfp('ImGui_DrawList_PathArcToFast')
    DrawList_PathArcToFast.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_int, c_int)(proc)
  args = (c_void_p(draw_list), c_double(center_x), c_double(center_y), c_double(radius), c_int(a_min_of_12), c_int(a_max_of_12))
  DrawList_PathArcToFast.func(args[0], args[1], args[2], args[3], args[4], args[5])

def DrawList_PathBezierCubicCurveTo(draw_list, p2_x, p2_y, p3_x, p3_y, p4_x, p4_y, num_segmentsInOptional = None):
  if not hasattr(DrawList_PathBezierCubicCurveTo, 'func'):
    proc = rpr_getfp('ImGui_DrawList_PathBezierCubicCurveTo')
    DrawList_PathBezierCubicCurveTo.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_double, c_double, c_double, c_void_p)(proc)
  args = (c_void_p(draw_list), c_double(p2_x), c_double(p2_y), c_double(p3_x), c_double(p3_y), c_double(p4_x), c_double(p4_y), c_int(num_segmentsInOptional) if num_segmentsInOptional != None else None)
  DrawList_PathBezierCubicCurveTo.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], byref(args[7]) if args[7] != None else None)

def DrawList_PathBezierQuadraticCurveTo(draw_list, p2_x, p2_y, p3_x, p3_y, num_segmentsInOptional = None):
  if not hasattr(DrawList_PathBezierQuadraticCurveTo, 'func'):
    proc = rpr_getfp('ImGui_DrawList_PathBezierQuadraticCurveTo')
    DrawList_PathBezierQuadraticCurveTo.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_double, c_void_p)(proc)
  args = (c_void_p(draw_list), c_double(p2_x), c_double(p2_y), c_double(p3_x), c_double(p3_y), c_int(num_segmentsInOptional) if num_segmentsInOptional != None else None)
  DrawList_PathBezierQuadraticCurveTo.func(args[0], args[1], args[2], args[3], args[4], byref(args[5]) if args[5] != None else None)

def DrawList_PathClear(draw_list):
  if not hasattr(DrawList_PathClear, 'func'):
    proc = rpr_getfp('ImGui_DrawList_PathClear')
    DrawList_PathClear.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(draw_list),)
  DrawList_PathClear.func(args[0])

def DrawList_PathEllipticalArcTo(draw_list, center_x, center_y, radius_x, radius_y, rot, a_min, a_max, num_segmentsInOptional = None):
  if not hasattr(DrawList_PathEllipticalArcTo, 'func'):
    proc = rpr_getfp('ImGui_DrawList_PathEllipticalArcTo')
    DrawList_PathEllipticalArcTo.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_double, c_double, c_double, c_double, c_void_p)(proc)
  args = (c_void_p(draw_list), c_double(center_x), c_double(center_y), c_double(radius_x), c_double(radius_y), c_double(rot), c_double(a_min), c_double(a_max), c_int(num_segmentsInOptional) if num_segmentsInOptional != None else None)
  DrawList_PathEllipticalArcTo.func(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], byref(args[8]) if args[8] != None else None)

def DrawList_PathFillConcave(draw_list, col_rgba):
  if not hasattr(DrawList_PathFillConcave, 'func'):
    proc = rpr_getfp('ImGui_DrawList_PathFillConcave')
    DrawList_PathFillConcave.func = CFUNCTYPE(None, c_void_p, c_int)(proc)
  args = (c_void_p(draw_list), c_int(col_rgba))
  DrawList_PathFillConcave.func(args[0], args[1])

def DrawList_PathFillConvex(draw_list, col_rgba):
  if not hasattr(DrawList_PathFillConvex, 'func'):
    proc = rpr_getfp('ImGui_DrawList_PathFillConvex')
    DrawList_PathFillConvex.func = CFUNCTYPE(None, c_void_p, c_int)(proc)
  args = (c_void_p(draw_list), c_int(col_rgba))
  DrawList_PathFillConvex.func(args[0], args[1])

def DrawList_PathLineTo(draw_list, pos_x, pos_y):
  if not hasattr(DrawList_PathLineTo, 'func'):
    proc = rpr_getfp('ImGui_DrawList_PathLineTo')
    DrawList_PathLineTo.func = CFUNCTYPE(None, c_void_p, c_double, c_double)(proc)
  args = (c_void_p(draw_list), c_double(pos_x), c_double(pos_y))
  DrawList_PathLineTo.func(args[0], args[1], args[2])

def DrawList_PathRect(draw_list, rect_min_x, rect_min_y, rect_max_x, rect_max_y, roundingInOptional = None, flagsInOptional = None):
  if not hasattr(DrawList_PathRect, 'func'):
    proc = rpr_getfp('ImGui_DrawList_PathRect')
    DrawList_PathRect.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_double, c_void_p, c_void_p)(proc)
  args = (c_void_p(draw_list), c_double(rect_min_x), c_double(rect_min_y), c_double(rect_max_x), c_double(rect_max_y), c_double(roundingInOptional) if roundingInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  DrawList_PathRect.func(args[0], args[1], args[2], args[3], args[4], byref(args[5]) if args[5] != None else None, byref(args[6]) if args[6] != None else None)

def DrawList_PathStroke(draw_list, col_rgba, flagsInOptional = None, thicknessInOptional = None):
  if not hasattr(DrawList_PathStroke, 'func'):
    proc = rpr_getfp('ImGui_DrawList_PathStroke')
    DrawList_PathStroke.func = CFUNCTYPE(None, c_void_p, c_int, c_void_p, c_void_p)(proc)
  args = (c_void_p(draw_list), c_int(col_rgba), c_int(flagsInOptional) if flagsInOptional != None else None, c_double(thicknessInOptional) if thicknessInOptional != None else None)
  DrawList_PathStroke.func(args[0], args[1], byref(args[2]) if args[2] != None else None, byref(args[3]) if args[3] != None else None)

def CreateFont(family, flagsInOptional = None):
  if not hasattr(CreateFont, 'func'):
    proc = rpr_getfp('ImGui_CreateFont')
    CreateFont.func = CFUNCTYPE(c_void_p, c_char_p, c_void_p)(proc)
  args = (rpr_packsc(family), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = CreateFont.func(args[0], byref(args[1]) if args[1] != None else None)
  return rval

def CreateFontFromFile(file, indexInOptional = None, flagsInOptional = None):
  if not hasattr(CreateFontFromFile, 'func'):
    proc = rpr_getfp('ImGui_CreateFontFromFile')
    CreateFontFromFile.func = CFUNCTYPE(c_void_p, c_char_p, c_void_p, c_void_p)(proc)
  args = (rpr_packsc(file), c_int(indexInOptional) if indexInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = CreateFontFromFile.func(args[0], byref(args[1]) if args[1] != None else None, byref(args[2]) if args[2] != None else None)
  return rval

def CreateFontFromMem(data, indexInOptional = None, flagsInOptional = None):
  if not hasattr(CreateFontFromMem, 'func'):
    proc = rpr_getfp('ImGui_CreateFontFromMem')
    CreateFontFromMem.func = CFUNCTYPE(c_void_p, c_char_p, c_int, c_void_p, c_void_p)(proc)
  args = (rpr_packsc(data), c_int(len(data)+1), c_int(indexInOptional) if indexInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = CreateFontFromMem.func(args[0], args[1], byref(args[2]) if args[2] != None else None, byref(args[3]) if args[3] != None else None)
  return rval

def FontFlags_Bold():
  if not hasattr(FontFlags_Bold, 'func'):
    proc = rpr_getfp('ImGui_FontFlags_Bold')
    FontFlags_Bold.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(FontFlags_Bold, 'cache'):
    FontFlags_Bold.cache = FontFlags_Bold.func()
  return FontFlags_Bold.cache

def FontFlags_Italic():
  if not hasattr(FontFlags_Italic, 'func'):
    proc = rpr_getfp('ImGui_FontFlags_Italic')
    FontFlags_Italic.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(FontFlags_Italic, 'cache'):
    FontFlags_Italic.cache = FontFlags_Italic.func()
  return FontFlags_Italic.cache

def FontFlags_None():
  if not hasattr(FontFlags_None, 'func'):
    proc = rpr_getfp('ImGui_FontFlags_None')
    FontFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(FontFlags_None, 'cache'):
    FontFlags_None.cache = FontFlags_None.func()
  return FontFlags_None.cache

def GetFont(ctx):
  if not hasattr(GetFont, 'func'):
    proc = rpr_getfp('ImGui_GetFont')
    GetFont.func = CFUNCTYPE(c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetFont.func(args[0])
  return rval

def GetFontSize(ctx):
  if not hasattr(GetFontSize, 'func'):
    proc = rpr_getfp('ImGui_GetFontSize')
    GetFontSize.func = CFUNCTYPE(c_double, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetFontSize.func(args[0])
  return rval

def PopFont(ctx):
  if not hasattr(PopFont, 'func'):
    proc = rpr_getfp('ImGui_PopFont')
    PopFont.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  PopFont.func(args[0])

def PushFont(ctx, font, font_size_base_unscaled):
  if not hasattr(PushFont, 'func'):
    proc = rpr_getfp('ImGui_PushFont')
    PushFont.func = CFUNCTYPE(None, c_void_p, c_void_p, c_double)(proc)
  args = (c_void_p(ctx), c_void_p(font), c_double(font_size_base_unscaled))
  PushFont.func(args[0], args[1], args[2])

def CreateFunctionFromEEL(code):
  if not hasattr(CreateFunctionFromEEL, 'func'):
    proc = rpr_getfp('ImGui_CreateFunctionFromEEL')
    CreateFunctionFromEEL.func = CFUNCTYPE(c_void_p, c_char_p)(proc)
  args = (rpr_packsc(code),)
  rval = CreateFunctionFromEEL.func(args[0])
  return rval

def Function_Execute(func):
  if not hasattr(Function_Execute, 'func'):
    proc = rpr_getfp('ImGui_Function_Execute')
    Function_Execute.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(func),)
  Function_Execute.func(args[0])

def Function_GetValue(func, name):
  if not hasattr(Function_GetValue, 'func'):
    proc = rpr_getfp('ImGui_Function_GetValue')
    Function_GetValue.func = CFUNCTYPE(c_double, c_void_p, c_char_p)(proc)
  args = (c_void_p(func), rpr_packsc(name))
  rval = Function_GetValue.func(args[0], args[1])
  return rval

def Function_GetValue_Array(func, name, values):
  if not hasattr(Function_GetValue_Array, 'func'):
    proc = rpr_getfp('ImGui_Function_GetValue_Array')
    Function_GetValue_Array.func = CFUNCTYPE(None, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(func), rpr_packsc(name), c_void_p(values))
  Function_GetValue_Array.func(args[0], args[1], args[2])

def Function_GetValue_String(func, name):
  if not hasattr(Function_GetValue_String, 'func'):
    proc = rpr_getfp('ImGui_Function_GetValue_String')
    Function_GetValue_String.func = CFUNCTYPE(None, c_void_p, c_char_p, c_char_p, c_int)(proc)
  args = (c_void_p(func), rpr_packsc(name), rpr_packs(0), c_int(4096))
  Function_GetValue_String.func(args[0], args[1], args[2], args[3])
  return rpr_unpacks(args[2])

def Function_SetValue(func, name, value):
  if not hasattr(Function_SetValue, 'func'):
    proc = rpr_getfp('ImGui_Function_SetValue')
    Function_SetValue.func = CFUNCTYPE(None, c_void_p, c_char_p, c_double)(proc)
  args = (c_void_p(func), rpr_packsc(name), c_double(value))
  Function_SetValue.func(args[0], args[1], args[2])

def Function_SetValue_Array(func, name, values):
  if not hasattr(Function_SetValue_Array, 'func'):
    proc = rpr_getfp('ImGui_Function_SetValue_Array')
    Function_SetValue_Array.func = CFUNCTYPE(None, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(func), rpr_packsc(name), c_void_p(values))
  Function_SetValue_Array.func(args[0], args[1], args[2])

def Function_SetValue_String(func, name, value):
  if not hasattr(Function_SetValue_String, 'func'):
    proc = rpr_getfp('ImGui_Function_SetValue_String')
    Function_SetValue_String.func = CFUNCTYPE(None, c_void_p, c_char_p, c_char_p, c_int)(proc)
  args = (c_void_p(func), rpr_packsc(name), rpr_packsc(value), c_int(len(value)+1))
  Function_SetValue_String.func(args[0], args[1], args[2], args[3])

def CreateImage(file, flagsInOptional = None):
  if not hasattr(CreateImage, 'func'):
    proc = rpr_getfp('ImGui_CreateImage')
    CreateImage.func = CFUNCTYPE(c_void_p, c_char_p, c_void_p)(proc)
  args = (rpr_packsc(file), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = CreateImage.func(args[0], byref(args[1]) if args[1] != None else None)
  return rval

def CreateImageFromLICE(bitmap, flagsInOptional = None):
  if not hasattr(CreateImageFromLICE, 'func'):
    proc = rpr_getfp('ImGui_CreateImageFromLICE')
    CreateImageFromLICE.func = CFUNCTYPE(c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(bitmap), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = CreateImageFromLICE.func(args[0], byref(args[1]) if args[1] != None else None)
  return rval

def CreateImageFromMem(data, flagsInOptional = None):
  if not hasattr(CreateImageFromMem, 'func'):
    proc = rpr_getfp('ImGui_CreateImageFromMem')
    CreateImageFromMem.func = CFUNCTYPE(c_void_p, c_char_p, c_int, c_void_p)(proc)
  args = (rpr_packsc(data), c_int(len(data)+1), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = CreateImageFromMem.func(args[0], args[1], byref(args[2]) if args[2] != None else None)
  return rval

def CreateImageFromSize(width, height, flagsInOptional = None):
  if not hasattr(CreateImageFromSize, 'func'):
    proc = rpr_getfp('ImGui_CreateImageFromSize')
    CreateImageFromSize.func = CFUNCTYPE(c_void_p, c_int, c_int, c_void_p)(proc)
  args = (c_int(width), c_int(height), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = CreateImageFromSize.func(args[0], args[1], byref(args[2]) if args[2] != None else None)
  return rval

def Image(ctx, image, image_size_w, image_size_h, uv0_xInOptional = None, uv0_yInOptional = None, uv1_xInOptional = None, uv1_yInOptional = None):
  if not hasattr(Image, 'func'):
    proc = rpr_getfp('ImGui_Image')
    Image.func = CFUNCTYPE(None, c_void_p, c_void_p, c_double, c_double, c_void_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_void_p(image), c_double(image_size_w), c_double(image_size_h), c_double(uv0_xInOptional) if uv0_xInOptional != None else None, c_double(uv0_yInOptional) if uv0_yInOptional != None else None, c_double(uv1_xInOptional) if uv1_xInOptional != None else None, c_double(uv1_yInOptional) if uv1_yInOptional != None else None)
  Image.func(args[0], args[1], args[2], args[3], byref(args[4]) if args[4] != None else None, byref(args[5]) if args[5] != None else None, byref(args[6]) if args[6] != None else None, byref(args[7]) if args[7] != None else None)

def ImageButton(ctx, str_id, image, image_size_w, image_size_h, uv0_xInOptional = None, uv0_yInOptional = None, uv1_xInOptional = None, uv1_yInOptional = None, bg_col_rgbaInOptional = None, tint_col_rgbaInOptional = None):
  if not hasattr(ImageButton, 'func'):
    proc = rpr_getfp('ImGui_ImageButton')
    ImageButton.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_double, c_double, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(str_id), c_void_p(image), c_double(image_size_w), c_double(image_size_h), c_double(uv0_xInOptional) if uv0_xInOptional != None else None, c_double(uv0_yInOptional) if uv0_yInOptional != None else None, c_double(uv1_xInOptional) if uv1_xInOptional != None else None, c_double(uv1_yInOptional) if uv1_yInOptional != None else None, c_int(bg_col_rgbaInOptional) if bg_col_rgbaInOptional != None else None, c_int(tint_col_rgbaInOptional) if tint_col_rgbaInOptional != None else None)
  rval = ImageButton.func(args[0], args[1], args[2], args[3], args[4], byref(args[5]) if args[5] != None else None, byref(args[6]) if args[6] != None else None, byref(args[7]) if args[7] != None else None, byref(args[8]) if args[8] != None else None, byref(args[9]) if args[9] != None else None, byref(args[10]) if args[10] != None else None)
  return rval

def ImageWithBg(ctx, image, image_size_w, image_size_h, uv0_xInOptional = None, uv0_yInOptional = None, uv1_xInOptional = None, uv1_yInOptional = None, bg_col_rgbaInOptional = None, tint_col_rgbaInOptional = None):
  if not hasattr(ImageWithBg, 'func'):
    proc = rpr_getfp('ImGui_ImageWithBg')
    ImageWithBg.func = CFUNCTYPE(None, c_void_p, c_void_p, c_double, c_double, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_void_p(image), c_double(image_size_w), c_double(image_size_h), c_double(uv0_xInOptional) if uv0_xInOptional != None else None, c_double(uv0_yInOptional) if uv0_yInOptional != None else None, c_double(uv1_xInOptional) if uv1_xInOptional != None else None, c_double(uv1_yInOptional) if uv1_yInOptional != None else None, c_int(bg_col_rgbaInOptional) if bg_col_rgbaInOptional != None else None, c_int(tint_col_rgbaInOptional) if tint_col_rgbaInOptional != None else None)
  ImageWithBg.func(args[0], args[1], args[2], args[3], byref(args[4]) if args[4] != None else None, byref(args[5]) if args[5] != None else None, byref(args[6]) if args[6] != None else None, byref(args[7]) if args[7] != None else None, byref(args[8]) if args[8] != None else None, byref(args[9]) if args[9] != None else None)

def Image_GetPixels_Array(image, x, y, w, h, pixels, offsetInOptional = None, pitchInOptional = None):
  if not hasattr(Image_GetPixels_Array, 'func'):
    proc = rpr_getfp('ImGui_Image_GetPixels_Array')
    Image_GetPixels_Array.func = CFUNCTYPE(None, c_void_p, c_int, c_int, c_int, c_int, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(image), c_int(x), c_int(y), c_int(w), c_int(h), c_void_p(pixels), c_int(offsetInOptional) if offsetInOptional != None else None, c_int(pitchInOptional) if pitchInOptional != None else None)
  Image_GetPixels_Array.func(args[0], args[1], args[2], args[3], args[4], args[5], byref(args[6]) if args[6] != None else None, byref(args[7]) if args[7] != None else None)

def Image_GetSize(image):
  if not hasattr(Image_GetSize, 'func'):
    proc = rpr_getfp('ImGui_Image_GetSize')
    Image_GetSize.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(image), c_double(0), c_double(0))
  Image_GetSize.func(args[0], byref(args[1]), byref(args[2]))
  return float(args[1].value), float(args[2].value)

def Image_SetPixels_Array(image, x, y, w, h, pixels, offsetInOptional = None, pitchInOptional = None):
  if not hasattr(Image_SetPixels_Array, 'func'):
    proc = rpr_getfp('ImGui_Image_SetPixels_Array')
    Image_SetPixels_Array.func = CFUNCTYPE(None, c_void_p, c_int, c_int, c_int, c_int, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(image), c_int(x), c_int(y), c_int(w), c_int(h), c_void_p(pixels), c_int(offsetInOptional) if offsetInOptional != None else None, c_int(pitchInOptional) if pitchInOptional != None else None)
  Image_SetPixels_Array.func(args[0], args[1], args[2], args[3], args[4], args[5], byref(args[6]) if args[6] != None else None, byref(args[7]) if args[7] != None else None)

def CreateImageSet():
  if not hasattr(CreateImageSet, 'func'):
    proc = rpr_getfp('ImGui_CreateImageSet')
    CreateImageSet.func = CFUNCTYPE(c_void_p)(proc)
  rval = CreateImageSet.func()
  return rval

def ImageFlags_NoErrors():
  if not hasattr(ImageFlags_NoErrors, 'func'):
    proc = rpr_getfp('ImGui_ImageFlags_NoErrors')
    ImageFlags_NoErrors.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ImageFlags_NoErrors, 'cache'):
    ImageFlags_NoErrors.cache = ImageFlags_NoErrors.func()
  return ImageFlags_NoErrors.cache

def ImageFlags_None():
  if not hasattr(ImageFlags_None, 'func'):
    proc = rpr_getfp('ImGui_ImageFlags_None')
    ImageFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ImageFlags_None, 'cache'):
    ImageFlags_None.cache = ImageFlags_None.func()
  return ImageFlags_None.cache

def ImageSet_Add(set, scale, image):
  if not hasattr(ImageSet_Add, 'func'):
    proc = rpr_getfp('ImGui_ImageSet_Add')
    ImageSet_Add.func = CFUNCTYPE(None, c_void_p, c_double, c_void_p)(proc)
  args = (c_void_p(set), c_double(scale), c_void_p(image))
  ImageSet_Add.func(args[0], args[1], args[2])

def BeginDisabled(ctx, disabledInOptional = None):
  if not hasattr(BeginDisabled, 'func'):
    proc = rpr_getfp('ImGui_BeginDisabled')
    BeginDisabled.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_bool(disabledInOptional) if disabledInOptional != None else None)
  BeginDisabled.func(args[0], byref(args[1]) if args[1] != None else None)

def DebugStartItemPicker(ctx):
  if not hasattr(DebugStartItemPicker, 'func'):
    proc = rpr_getfp('ImGui_DebugStartItemPicker')
    DebugStartItemPicker.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  DebugStartItemPicker.func(args[0])

def EndDisabled(ctx):
  if not hasattr(EndDisabled, 'func'):
    proc = rpr_getfp('ImGui_EndDisabled')
    EndDisabled.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  EndDisabled.func(args[0])

def PopItemFlag(ctx):
  if not hasattr(PopItemFlag, 'func'):
    proc = rpr_getfp('ImGui_PopItemFlag')
    PopItemFlag.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  PopItemFlag.func(args[0])

def PushItemFlag(ctx, option, enabled):
  if not hasattr(PushItemFlag, 'func'):
    proc = rpr_getfp('ImGui_PushItemFlag')
    PushItemFlag.func = CFUNCTYPE(None, c_void_p, c_int, c_bool)(proc)
  args = (c_void_p(ctx), c_int(option), c_bool(enabled))
  PushItemFlag.func(args[0], args[1], args[2])

def SetNextItemAllowOverlap(ctx):
  if not hasattr(SetNextItemAllowOverlap, 'func'):
    proc = rpr_getfp('ImGui_SetNextItemAllowOverlap')
    SetNextItemAllowOverlap.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  SetNextItemAllowOverlap.func(args[0])

def CalcItemWidth(ctx):
  if not hasattr(CalcItemWidth, 'func'):
    proc = rpr_getfp('ImGui_CalcItemWidth')
    CalcItemWidth.func = CFUNCTYPE(c_double, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = CalcItemWidth.func(args[0])
  return rval

def GetItemRectMax(ctx):
  if not hasattr(GetItemRectMax, 'func'):
    proc = rpr_getfp('ImGui_GetItemRectMax')
    GetItemRectMax.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(0), c_double(0))
  GetItemRectMax.func(args[0], byref(args[1]), byref(args[2]))
  return float(args[1].value), float(args[2].value)

def GetItemRectMin(ctx):
  if not hasattr(GetItemRectMin, 'func'):
    proc = rpr_getfp('ImGui_GetItemRectMin')
    GetItemRectMin.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(0), c_double(0))
  GetItemRectMin.func(args[0], byref(args[1]), byref(args[2]))
  return float(args[1].value), float(args[2].value)

def GetItemRectSize(ctx):
  if not hasattr(GetItemRectSize, 'func'):
    proc = rpr_getfp('ImGui_GetItemRectSize')
    GetItemRectSize.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(0), c_double(0))
  GetItemRectSize.func(args[0], byref(args[1]), byref(args[2]))
  return float(args[1].value), float(args[2].value)

def PopItemWidth(ctx):
  if not hasattr(PopItemWidth, 'func'):
    proc = rpr_getfp('ImGui_PopItemWidth')
    PopItemWidth.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  PopItemWidth.func(args[0])

def PushItemWidth(ctx, item_width):
  if not hasattr(PushItemWidth, 'func'):
    proc = rpr_getfp('ImGui_PushItemWidth')
    PushItemWidth.func = CFUNCTYPE(None, c_void_p, c_double)(proc)
  args = (c_void_p(ctx), c_double(item_width))
  PushItemWidth.func(args[0], args[1])

def SetNextItemWidth(ctx, item_width):
  if not hasattr(SetNextItemWidth, 'func'):
    proc = rpr_getfp('ImGui_SetNextItemWidth')
    SetNextItemWidth.func = CFUNCTYPE(None, c_void_p, c_double)(proc)
  args = (c_void_p(ctx), c_double(item_width))
  SetNextItemWidth.func(args[0], args[1])

def SetItemDefaultFocus(ctx):
  if not hasattr(SetItemDefaultFocus, 'func'):
    proc = rpr_getfp('ImGui_SetItemDefaultFocus')
    SetItemDefaultFocus.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  SetItemDefaultFocus.func(args[0])

def SetKeyboardFocusHere(ctx, offsetInOptional = None):
  if not hasattr(SetKeyboardFocusHere, 'func'):
    proc = rpr_getfp('ImGui_SetKeyboardFocusHere')
    SetKeyboardFocusHere.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(offsetInOptional) if offsetInOptional != None else None)
  SetKeyboardFocusHere.func(args[0], byref(args[1]) if args[1] != None else None)

def SetNavCursorVisible(ctx, visible):
  if not hasattr(SetNavCursorVisible, 'func'):
    proc = rpr_getfp('ImGui_SetNavCursorVisible')
    SetNavCursorVisible.func = CFUNCTYPE(None, c_void_p, c_bool)(proc)
  args = (c_void_p(ctx), c_bool(visible))
  SetNavCursorVisible.func(args[0], args[1])

def HoveredFlags_AllowWhenBlockedByActiveItem():
  if not hasattr(HoveredFlags_AllowWhenBlockedByActiveItem, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_AllowWhenBlockedByActiveItem')
    HoveredFlags_AllowWhenBlockedByActiveItem.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_AllowWhenBlockedByActiveItem, 'cache'):
    HoveredFlags_AllowWhenBlockedByActiveItem.cache = HoveredFlags_AllowWhenBlockedByActiveItem.func()
  return HoveredFlags_AllowWhenBlockedByActiveItem.cache

def HoveredFlags_AllowWhenBlockedByPopup():
  if not hasattr(HoveredFlags_AllowWhenBlockedByPopup, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_AllowWhenBlockedByPopup')
    HoveredFlags_AllowWhenBlockedByPopup.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_AllowWhenBlockedByPopup, 'cache'):
    HoveredFlags_AllowWhenBlockedByPopup.cache = HoveredFlags_AllowWhenBlockedByPopup.func()
  return HoveredFlags_AllowWhenBlockedByPopup.cache

def HoveredFlags_ForTooltip():
  if not hasattr(HoveredFlags_ForTooltip, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_ForTooltip')
    HoveredFlags_ForTooltip.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_ForTooltip, 'cache'):
    HoveredFlags_ForTooltip.cache = HoveredFlags_ForTooltip.func()
  return HoveredFlags_ForTooltip.cache

def HoveredFlags_NoNavOverride():
  if not hasattr(HoveredFlags_NoNavOverride, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_NoNavOverride')
    HoveredFlags_NoNavOverride.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_NoNavOverride, 'cache'):
    HoveredFlags_NoNavOverride.cache = HoveredFlags_NoNavOverride.func()
  return HoveredFlags_NoNavOverride.cache

def HoveredFlags_None():
  if not hasattr(HoveredFlags_None, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_None')
    HoveredFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_None, 'cache'):
    HoveredFlags_None.cache = HoveredFlags_None.func()
  return HoveredFlags_None.cache

def HoveredFlags_Stationary():
  if not hasattr(HoveredFlags_Stationary, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_Stationary')
    HoveredFlags_Stationary.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_Stationary, 'cache'):
    HoveredFlags_Stationary.cache = HoveredFlags_Stationary.func()
  return HoveredFlags_Stationary.cache

def HoveredFlags_AllowWhenDisabled():
  if not hasattr(HoveredFlags_AllowWhenDisabled, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_AllowWhenDisabled')
    HoveredFlags_AllowWhenDisabled.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_AllowWhenDisabled, 'cache'):
    HoveredFlags_AllowWhenDisabled.cache = HoveredFlags_AllowWhenDisabled.func()
  return HoveredFlags_AllowWhenDisabled.cache

def HoveredFlags_AllowWhenOverlapped():
  if not hasattr(HoveredFlags_AllowWhenOverlapped, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_AllowWhenOverlapped')
    HoveredFlags_AllowWhenOverlapped.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_AllowWhenOverlapped, 'cache'):
    HoveredFlags_AllowWhenOverlapped.cache = HoveredFlags_AllowWhenOverlapped.func()
  return HoveredFlags_AllowWhenOverlapped.cache

def HoveredFlags_AllowWhenOverlappedByItem():
  if not hasattr(HoveredFlags_AllowWhenOverlappedByItem, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_AllowWhenOverlappedByItem')
    HoveredFlags_AllowWhenOverlappedByItem.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_AllowWhenOverlappedByItem, 'cache'):
    HoveredFlags_AllowWhenOverlappedByItem.cache = HoveredFlags_AllowWhenOverlappedByItem.func()
  return HoveredFlags_AllowWhenOverlappedByItem.cache

def HoveredFlags_AllowWhenOverlappedByWindow():
  if not hasattr(HoveredFlags_AllowWhenOverlappedByWindow, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_AllowWhenOverlappedByWindow')
    HoveredFlags_AllowWhenOverlappedByWindow.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_AllowWhenOverlappedByWindow, 'cache'):
    HoveredFlags_AllowWhenOverlappedByWindow.cache = HoveredFlags_AllowWhenOverlappedByWindow.func()
  return HoveredFlags_AllowWhenOverlappedByWindow.cache

def HoveredFlags_RectOnly():
  if not hasattr(HoveredFlags_RectOnly, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_RectOnly')
    HoveredFlags_RectOnly.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_RectOnly, 'cache'):
    HoveredFlags_RectOnly.cache = HoveredFlags_RectOnly.func()
  return HoveredFlags_RectOnly.cache

def HoveredFlags_DelayNone():
  if not hasattr(HoveredFlags_DelayNone, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_DelayNone')
    HoveredFlags_DelayNone.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_DelayNone, 'cache'):
    HoveredFlags_DelayNone.cache = HoveredFlags_DelayNone.func()
  return HoveredFlags_DelayNone.cache

def HoveredFlags_DelayNormal():
  if not hasattr(HoveredFlags_DelayNormal, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_DelayNormal')
    HoveredFlags_DelayNormal.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_DelayNormal, 'cache'):
    HoveredFlags_DelayNormal.cache = HoveredFlags_DelayNormal.func()
  return HoveredFlags_DelayNormal.cache

def HoveredFlags_DelayShort():
  if not hasattr(HoveredFlags_DelayShort, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_DelayShort')
    HoveredFlags_DelayShort.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_DelayShort, 'cache'):
    HoveredFlags_DelayShort.cache = HoveredFlags_DelayShort.func()
  return HoveredFlags_DelayShort.cache

def HoveredFlags_NoSharedDelay():
  if not hasattr(HoveredFlags_NoSharedDelay, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_NoSharedDelay')
    HoveredFlags_NoSharedDelay.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_NoSharedDelay, 'cache'):
    HoveredFlags_NoSharedDelay.cache = HoveredFlags_NoSharedDelay.func()
  return HoveredFlags_NoSharedDelay.cache

def HoveredFlags_AnyWindow():
  if not hasattr(HoveredFlags_AnyWindow, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_AnyWindow')
    HoveredFlags_AnyWindow.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_AnyWindow, 'cache'):
    HoveredFlags_AnyWindow.cache = HoveredFlags_AnyWindow.func()
  return HoveredFlags_AnyWindow.cache

def HoveredFlags_ChildWindows():
  if not hasattr(HoveredFlags_ChildWindows, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_ChildWindows')
    HoveredFlags_ChildWindows.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_ChildWindows, 'cache'):
    HoveredFlags_ChildWindows.cache = HoveredFlags_ChildWindows.func()
  return HoveredFlags_ChildWindows.cache

def HoveredFlags_DockHierarchy():
  if not hasattr(HoveredFlags_DockHierarchy, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_DockHierarchy')
    HoveredFlags_DockHierarchy.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_DockHierarchy, 'cache'):
    HoveredFlags_DockHierarchy.cache = HoveredFlags_DockHierarchy.func()
  return HoveredFlags_DockHierarchy.cache

def HoveredFlags_NoPopupHierarchy():
  if not hasattr(HoveredFlags_NoPopupHierarchy, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_NoPopupHierarchy')
    HoveredFlags_NoPopupHierarchy.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_NoPopupHierarchy, 'cache'):
    HoveredFlags_NoPopupHierarchy.cache = HoveredFlags_NoPopupHierarchy.func()
  return HoveredFlags_NoPopupHierarchy.cache

def HoveredFlags_RootAndChildWindows():
  if not hasattr(HoveredFlags_RootAndChildWindows, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_RootAndChildWindows')
    HoveredFlags_RootAndChildWindows.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_RootAndChildWindows, 'cache'):
    HoveredFlags_RootAndChildWindows.cache = HoveredFlags_RootAndChildWindows.func()
  return HoveredFlags_RootAndChildWindows.cache

def HoveredFlags_RootWindow():
  if not hasattr(HoveredFlags_RootWindow, 'func'):
    proc = rpr_getfp('ImGui_HoveredFlags_RootWindow')
    HoveredFlags_RootWindow.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(HoveredFlags_RootWindow, 'cache'):
    HoveredFlags_RootWindow.cache = HoveredFlags_RootWindow.func()
  return HoveredFlags_RootWindow.cache

def ItemFlags_AllowDuplicateId():
  if not hasattr(ItemFlags_AllowDuplicateId, 'func'):
    proc = rpr_getfp('ImGui_ItemFlags_AllowDuplicateId')
    ItemFlags_AllowDuplicateId.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ItemFlags_AllowDuplicateId, 'cache'):
    ItemFlags_AllowDuplicateId.cache = ItemFlags_AllowDuplicateId.func()
  return ItemFlags_AllowDuplicateId.cache

def ItemFlags_AutoClosePopups():
  if not hasattr(ItemFlags_AutoClosePopups, 'func'):
    proc = rpr_getfp('ImGui_ItemFlags_AutoClosePopups')
    ItemFlags_AutoClosePopups.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ItemFlags_AutoClosePopups, 'cache'):
    ItemFlags_AutoClosePopups.cache = ItemFlags_AutoClosePopups.func()
  return ItemFlags_AutoClosePopups.cache

def ItemFlags_ButtonRepeat():
  if not hasattr(ItemFlags_ButtonRepeat, 'func'):
    proc = rpr_getfp('ImGui_ItemFlags_ButtonRepeat')
    ItemFlags_ButtonRepeat.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ItemFlags_ButtonRepeat, 'cache'):
    ItemFlags_ButtonRepeat.cache = ItemFlags_ButtonRepeat.func()
  return ItemFlags_ButtonRepeat.cache

def ItemFlags_NoNav():
  if not hasattr(ItemFlags_NoNav, 'func'):
    proc = rpr_getfp('ImGui_ItemFlags_NoNav')
    ItemFlags_NoNav.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ItemFlags_NoNav, 'cache'):
    ItemFlags_NoNav.cache = ItemFlags_NoNav.func()
  return ItemFlags_NoNav.cache

def ItemFlags_NoNavDefaultFocus():
  if not hasattr(ItemFlags_NoNavDefaultFocus, 'func'):
    proc = rpr_getfp('ImGui_ItemFlags_NoNavDefaultFocus')
    ItemFlags_NoNavDefaultFocus.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ItemFlags_NoNavDefaultFocus, 'cache'):
    ItemFlags_NoNavDefaultFocus.cache = ItemFlags_NoNavDefaultFocus.func()
  return ItemFlags_NoNavDefaultFocus.cache

def ItemFlags_NoTabStop():
  if not hasattr(ItemFlags_NoTabStop, 'func'):
    proc = rpr_getfp('ImGui_ItemFlags_NoTabStop')
    ItemFlags_NoTabStop.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ItemFlags_NoTabStop, 'cache'):
    ItemFlags_NoTabStop.cache = ItemFlags_NoTabStop.func()
  return ItemFlags_NoTabStop.cache

def ItemFlags_None():
  if not hasattr(ItemFlags_None, 'func'):
    proc = rpr_getfp('ImGui_ItemFlags_None')
    ItemFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ItemFlags_None, 'cache'):
    ItemFlags_None.cache = ItemFlags_None.func()
  return ItemFlags_None.cache

def IsAnyItemActive(ctx):
  if not hasattr(IsAnyItemActive, 'func'):
    proc = rpr_getfp('ImGui_IsAnyItemActive')
    IsAnyItemActive.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = IsAnyItemActive.func(args[0])
  return rval

def IsAnyItemFocused(ctx):
  if not hasattr(IsAnyItemFocused, 'func'):
    proc = rpr_getfp('ImGui_IsAnyItemFocused')
    IsAnyItemFocused.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = IsAnyItemFocused.func(args[0])
  return rval

def IsAnyItemHovered(ctx):
  if not hasattr(IsAnyItemHovered, 'func'):
    proc = rpr_getfp('ImGui_IsAnyItemHovered')
    IsAnyItemHovered.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = IsAnyItemHovered.func(args[0])
  return rval

def IsItemActivated(ctx):
  if not hasattr(IsItemActivated, 'func'):
    proc = rpr_getfp('ImGui_IsItemActivated')
    IsItemActivated.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = IsItemActivated.func(args[0])
  return rval

def IsItemActive(ctx):
  if not hasattr(IsItemActive, 'func'):
    proc = rpr_getfp('ImGui_IsItemActive')
    IsItemActive.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = IsItemActive.func(args[0])
  return rval

def IsItemClicked(ctx, mouse_buttonInOptional = None):
  if not hasattr(IsItemClicked, 'func'):
    proc = rpr_getfp('ImGui_IsItemClicked')
    IsItemClicked.func = CFUNCTYPE(c_bool, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(mouse_buttonInOptional) if mouse_buttonInOptional != None else None)
  rval = IsItemClicked.func(args[0], byref(args[1]) if args[1] != None else None)
  return rval

def IsItemDeactivated(ctx):
  if not hasattr(IsItemDeactivated, 'func'):
    proc = rpr_getfp('ImGui_IsItemDeactivated')
    IsItemDeactivated.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = IsItemDeactivated.func(args[0])
  return rval

def IsItemDeactivatedAfterEdit(ctx):
  if not hasattr(IsItemDeactivatedAfterEdit, 'func'):
    proc = rpr_getfp('ImGui_IsItemDeactivatedAfterEdit')
    IsItemDeactivatedAfterEdit.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = IsItemDeactivatedAfterEdit.func(args[0])
  return rval

def IsItemEdited(ctx):
  if not hasattr(IsItemEdited, 'func'):
    proc = rpr_getfp('ImGui_IsItemEdited')
    IsItemEdited.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = IsItemEdited.func(args[0])
  return rval

def IsItemFocused(ctx):
  if not hasattr(IsItemFocused, 'func'):
    proc = rpr_getfp('ImGui_IsItemFocused')
    IsItemFocused.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = IsItemFocused.func(args[0])
  return rval

def IsItemHovered(ctx, flagsInOptional = None):
  if not hasattr(IsItemHovered, 'func'):
    proc = rpr_getfp('ImGui_IsItemHovered')
    IsItemHovered.func = CFUNCTYPE(c_bool, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = IsItemHovered.func(args[0], byref(args[1]) if args[1] != None else None)
  return rval

def IsItemVisible(ctx):
  if not hasattr(IsItemVisible, 'func'):
    proc = rpr_getfp('ImGui_IsItemVisible')
    IsItemVisible.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = IsItemVisible.func(args[0])
  return rval

def GetInputQueueCharacter(ctx, idx):
  if not hasattr(GetInputQueueCharacter, 'func'):
    proc = rpr_getfp('ImGui_GetInputQueueCharacter')
    GetInputQueueCharacter.func = CFUNCTYPE(c_bool, c_void_p, c_int, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(idx), c_int(0))
  rval = GetInputQueueCharacter.func(args[0], args[1], byref(args[2]))
  return rval, int(args[2].value)

def GetKeyDownDuration(ctx, key):
  if not hasattr(GetKeyDownDuration, 'func'):
    proc = rpr_getfp('ImGui_GetKeyDownDuration')
    GetKeyDownDuration.func = CFUNCTYPE(c_double, c_void_p, c_int)(proc)
  args = (c_void_p(ctx), c_int(key))
  rval = GetKeyDownDuration.func(args[0], args[1])
  return rval

def GetKeyMods(ctx):
  if not hasattr(GetKeyMods, 'func'):
    proc = rpr_getfp('ImGui_GetKeyMods')
    GetKeyMods.func = CFUNCTYPE(c_int, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetKeyMods.func(args[0])
  return rval

def GetKeyPressedAmount(ctx, key, repeat_delay, rate):
  if not hasattr(GetKeyPressedAmount, 'func'):
    proc = rpr_getfp('ImGui_GetKeyPressedAmount')
    GetKeyPressedAmount.func = CFUNCTYPE(c_int, c_void_p, c_int, c_double, c_double)(proc)
  args = (c_void_p(ctx), c_int(key), c_double(repeat_delay), c_double(rate))
  rval = GetKeyPressedAmount.func(args[0], args[1], args[2], args[3])
  return rval

def IsKeyDown(ctx, key):
  if not hasattr(IsKeyDown, 'func'):
    proc = rpr_getfp('ImGui_IsKeyDown')
    IsKeyDown.func = CFUNCTYPE(c_bool, c_void_p, c_int)(proc)
  args = (c_void_p(ctx), c_int(key))
  rval = IsKeyDown.func(args[0], args[1])
  return rval

def IsKeyPressed(ctx, key, repeatInOptional = None):
  if not hasattr(IsKeyPressed, 'func'):
    proc = rpr_getfp('ImGui_IsKeyPressed')
    IsKeyPressed.func = CFUNCTYPE(c_bool, c_void_p, c_int, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(key), c_bool(repeatInOptional) if repeatInOptional != None else None)
  rval = IsKeyPressed.func(args[0], args[1], byref(args[2]) if args[2] != None else None)
  return rval

def IsKeyReleased(ctx, key):
  if not hasattr(IsKeyReleased, 'func'):
    proc = rpr_getfp('ImGui_IsKeyReleased')
    IsKeyReleased.func = CFUNCTYPE(c_bool, c_void_p, c_int)(proc)
  args = (c_void_p(ctx), c_int(key))
  rval = IsKeyReleased.func(args[0], args[1])
  return rval

def SetNextFrameWantCaptureKeyboard(ctx, want_capture_keyboard):
  if not hasattr(SetNextFrameWantCaptureKeyboard, 'func'):
    proc = rpr_getfp('ImGui_SetNextFrameWantCaptureKeyboard')
    SetNextFrameWantCaptureKeyboard.func = CFUNCTYPE(None, c_void_p, c_bool)(proc)
  args = (c_void_p(ctx), c_bool(want_capture_keyboard))
  SetNextFrameWantCaptureKeyboard.func(args[0], args[1])

def Key_0():
  if not hasattr(Key_0, 'func'):
    proc = rpr_getfp('ImGui_Key_0')
    Key_0.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_0, 'cache'):
    Key_0.cache = Key_0.func()
  return Key_0.cache

def Key_1():
  if not hasattr(Key_1, 'func'):
    proc = rpr_getfp('ImGui_Key_1')
    Key_1.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_1, 'cache'):
    Key_1.cache = Key_1.func()
  return Key_1.cache

def Key_2():
  if not hasattr(Key_2, 'func'):
    proc = rpr_getfp('ImGui_Key_2')
    Key_2.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_2, 'cache'):
    Key_2.cache = Key_2.func()
  return Key_2.cache

def Key_3():
  if not hasattr(Key_3, 'func'):
    proc = rpr_getfp('ImGui_Key_3')
    Key_3.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_3, 'cache'):
    Key_3.cache = Key_3.func()
  return Key_3.cache

def Key_4():
  if not hasattr(Key_4, 'func'):
    proc = rpr_getfp('ImGui_Key_4')
    Key_4.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_4, 'cache'):
    Key_4.cache = Key_4.func()
  return Key_4.cache

def Key_5():
  if not hasattr(Key_5, 'func'):
    proc = rpr_getfp('ImGui_Key_5')
    Key_5.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_5, 'cache'):
    Key_5.cache = Key_5.func()
  return Key_5.cache

def Key_6():
  if not hasattr(Key_6, 'func'):
    proc = rpr_getfp('ImGui_Key_6')
    Key_6.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_6, 'cache'):
    Key_6.cache = Key_6.func()
  return Key_6.cache

def Key_7():
  if not hasattr(Key_7, 'func'):
    proc = rpr_getfp('ImGui_Key_7')
    Key_7.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_7, 'cache'):
    Key_7.cache = Key_7.func()
  return Key_7.cache

def Key_8():
  if not hasattr(Key_8, 'func'):
    proc = rpr_getfp('ImGui_Key_8')
    Key_8.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_8, 'cache'):
    Key_8.cache = Key_8.func()
  return Key_8.cache

def Key_9():
  if not hasattr(Key_9, 'func'):
    proc = rpr_getfp('ImGui_Key_9')
    Key_9.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_9, 'cache'):
    Key_9.cache = Key_9.func()
  return Key_9.cache

def Key_A():
  if not hasattr(Key_A, 'func'):
    proc = rpr_getfp('ImGui_Key_A')
    Key_A.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_A, 'cache'):
    Key_A.cache = Key_A.func()
  return Key_A.cache

def Key_Apostrophe():
  if not hasattr(Key_Apostrophe, 'func'):
    proc = rpr_getfp('ImGui_Key_Apostrophe')
    Key_Apostrophe.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Apostrophe, 'cache'):
    Key_Apostrophe.cache = Key_Apostrophe.func()
  return Key_Apostrophe.cache

def Key_AppBack():
  if not hasattr(Key_AppBack, 'func'):
    proc = rpr_getfp('ImGui_Key_AppBack')
    Key_AppBack.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_AppBack, 'cache'):
    Key_AppBack.cache = Key_AppBack.func()
  return Key_AppBack.cache

def Key_AppForward():
  if not hasattr(Key_AppForward, 'func'):
    proc = rpr_getfp('ImGui_Key_AppForward')
    Key_AppForward.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_AppForward, 'cache'):
    Key_AppForward.cache = Key_AppForward.func()
  return Key_AppForward.cache

def Key_B():
  if not hasattr(Key_B, 'func'):
    proc = rpr_getfp('ImGui_Key_B')
    Key_B.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_B, 'cache'):
    Key_B.cache = Key_B.func()
  return Key_B.cache

def Key_Backslash():
  if not hasattr(Key_Backslash, 'func'):
    proc = rpr_getfp('ImGui_Key_Backslash')
    Key_Backslash.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Backslash, 'cache'):
    Key_Backslash.cache = Key_Backslash.func()
  return Key_Backslash.cache

def Key_Backspace():
  if not hasattr(Key_Backspace, 'func'):
    proc = rpr_getfp('ImGui_Key_Backspace')
    Key_Backspace.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Backspace, 'cache'):
    Key_Backspace.cache = Key_Backspace.func()
  return Key_Backspace.cache

def Key_C():
  if not hasattr(Key_C, 'func'):
    proc = rpr_getfp('ImGui_Key_C')
    Key_C.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_C, 'cache'):
    Key_C.cache = Key_C.func()
  return Key_C.cache

def Key_CapsLock():
  if not hasattr(Key_CapsLock, 'func'):
    proc = rpr_getfp('ImGui_Key_CapsLock')
    Key_CapsLock.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_CapsLock, 'cache'):
    Key_CapsLock.cache = Key_CapsLock.func()
  return Key_CapsLock.cache

def Key_Comma():
  if not hasattr(Key_Comma, 'func'):
    proc = rpr_getfp('ImGui_Key_Comma')
    Key_Comma.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Comma, 'cache'):
    Key_Comma.cache = Key_Comma.func()
  return Key_Comma.cache

def Key_D():
  if not hasattr(Key_D, 'func'):
    proc = rpr_getfp('ImGui_Key_D')
    Key_D.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_D, 'cache'):
    Key_D.cache = Key_D.func()
  return Key_D.cache

def Key_Delete():
  if not hasattr(Key_Delete, 'func'):
    proc = rpr_getfp('ImGui_Key_Delete')
    Key_Delete.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Delete, 'cache'):
    Key_Delete.cache = Key_Delete.func()
  return Key_Delete.cache

def Key_DownArrow():
  if not hasattr(Key_DownArrow, 'func'):
    proc = rpr_getfp('ImGui_Key_DownArrow')
    Key_DownArrow.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_DownArrow, 'cache'):
    Key_DownArrow.cache = Key_DownArrow.func()
  return Key_DownArrow.cache

def Key_E():
  if not hasattr(Key_E, 'func'):
    proc = rpr_getfp('ImGui_Key_E')
    Key_E.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_E, 'cache'):
    Key_E.cache = Key_E.func()
  return Key_E.cache

def Key_End():
  if not hasattr(Key_End, 'func'):
    proc = rpr_getfp('ImGui_Key_End')
    Key_End.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_End, 'cache'):
    Key_End.cache = Key_End.func()
  return Key_End.cache

def Key_Enter():
  if not hasattr(Key_Enter, 'func'):
    proc = rpr_getfp('ImGui_Key_Enter')
    Key_Enter.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Enter, 'cache'):
    Key_Enter.cache = Key_Enter.func()
  return Key_Enter.cache

def Key_Equal():
  if not hasattr(Key_Equal, 'func'):
    proc = rpr_getfp('ImGui_Key_Equal')
    Key_Equal.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Equal, 'cache'):
    Key_Equal.cache = Key_Equal.func()
  return Key_Equal.cache

def Key_Escape():
  if not hasattr(Key_Escape, 'func'):
    proc = rpr_getfp('ImGui_Key_Escape')
    Key_Escape.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Escape, 'cache'):
    Key_Escape.cache = Key_Escape.func()
  return Key_Escape.cache

def Key_F():
  if not hasattr(Key_F, 'func'):
    proc = rpr_getfp('ImGui_Key_F')
    Key_F.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F, 'cache'):
    Key_F.cache = Key_F.func()
  return Key_F.cache

def Key_F1():
  if not hasattr(Key_F1, 'func'):
    proc = rpr_getfp('ImGui_Key_F1')
    Key_F1.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F1, 'cache'):
    Key_F1.cache = Key_F1.func()
  return Key_F1.cache

def Key_F10():
  if not hasattr(Key_F10, 'func'):
    proc = rpr_getfp('ImGui_Key_F10')
    Key_F10.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F10, 'cache'):
    Key_F10.cache = Key_F10.func()
  return Key_F10.cache

def Key_F11():
  if not hasattr(Key_F11, 'func'):
    proc = rpr_getfp('ImGui_Key_F11')
    Key_F11.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F11, 'cache'):
    Key_F11.cache = Key_F11.func()
  return Key_F11.cache

def Key_F12():
  if not hasattr(Key_F12, 'func'):
    proc = rpr_getfp('ImGui_Key_F12')
    Key_F12.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F12, 'cache'):
    Key_F12.cache = Key_F12.func()
  return Key_F12.cache

def Key_F13():
  if not hasattr(Key_F13, 'func'):
    proc = rpr_getfp('ImGui_Key_F13')
    Key_F13.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F13, 'cache'):
    Key_F13.cache = Key_F13.func()
  return Key_F13.cache

def Key_F14():
  if not hasattr(Key_F14, 'func'):
    proc = rpr_getfp('ImGui_Key_F14')
    Key_F14.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F14, 'cache'):
    Key_F14.cache = Key_F14.func()
  return Key_F14.cache

def Key_F15():
  if not hasattr(Key_F15, 'func'):
    proc = rpr_getfp('ImGui_Key_F15')
    Key_F15.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F15, 'cache'):
    Key_F15.cache = Key_F15.func()
  return Key_F15.cache

def Key_F16():
  if not hasattr(Key_F16, 'func'):
    proc = rpr_getfp('ImGui_Key_F16')
    Key_F16.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F16, 'cache'):
    Key_F16.cache = Key_F16.func()
  return Key_F16.cache

def Key_F17():
  if not hasattr(Key_F17, 'func'):
    proc = rpr_getfp('ImGui_Key_F17')
    Key_F17.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F17, 'cache'):
    Key_F17.cache = Key_F17.func()
  return Key_F17.cache

def Key_F18():
  if not hasattr(Key_F18, 'func'):
    proc = rpr_getfp('ImGui_Key_F18')
    Key_F18.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F18, 'cache'):
    Key_F18.cache = Key_F18.func()
  return Key_F18.cache

def Key_F19():
  if not hasattr(Key_F19, 'func'):
    proc = rpr_getfp('ImGui_Key_F19')
    Key_F19.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F19, 'cache'):
    Key_F19.cache = Key_F19.func()
  return Key_F19.cache

def Key_F2():
  if not hasattr(Key_F2, 'func'):
    proc = rpr_getfp('ImGui_Key_F2')
    Key_F2.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F2, 'cache'):
    Key_F2.cache = Key_F2.func()
  return Key_F2.cache

def Key_F20():
  if not hasattr(Key_F20, 'func'):
    proc = rpr_getfp('ImGui_Key_F20')
    Key_F20.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F20, 'cache'):
    Key_F20.cache = Key_F20.func()
  return Key_F20.cache

def Key_F21():
  if not hasattr(Key_F21, 'func'):
    proc = rpr_getfp('ImGui_Key_F21')
    Key_F21.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F21, 'cache'):
    Key_F21.cache = Key_F21.func()
  return Key_F21.cache

def Key_F22():
  if not hasattr(Key_F22, 'func'):
    proc = rpr_getfp('ImGui_Key_F22')
    Key_F22.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F22, 'cache'):
    Key_F22.cache = Key_F22.func()
  return Key_F22.cache

def Key_F23():
  if not hasattr(Key_F23, 'func'):
    proc = rpr_getfp('ImGui_Key_F23')
    Key_F23.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F23, 'cache'):
    Key_F23.cache = Key_F23.func()
  return Key_F23.cache

def Key_F24():
  if not hasattr(Key_F24, 'func'):
    proc = rpr_getfp('ImGui_Key_F24')
    Key_F24.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F24, 'cache'):
    Key_F24.cache = Key_F24.func()
  return Key_F24.cache

def Key_F3():
  if not hasattr(Key_F3, 'func'):
    proc = rpr_getfp('ImGui_Key_F3')
    Key_F3.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F3, 'cache'):
    Key_F3.cache = Key_F3.func()
  return Key_F3.cache

def Key_F4():
  if not hasattr(Key_F4, 'func'):
    proc = rpr_getfp('ImGui_Key_F4')
    Key_F4.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F4, 'cache'):
    Key_F4.cache = Key_F4.func()
  return Key_F4.cache

def Key_F5():
  if not hasattr(Key_F5, 'func'):
    proc = rpr_getfp('ImGui_Key_F5')
    Key_F5.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F5, 'cache'):
    Key_F5.cache = Key_F5.func()
  return Key_F5.cache

def Key_F6():
  if not hasattr(Key_F6, 'func'):
    proc = rpr_getfp('ImGui_Key_F6')
    Key_F6.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F6, 'cache'):
    Key_F6.cache = Key_F6.func()
  return Key_F6.cache

def Key_F7():
  if not hasattr(Key_F7, 'func'):
    proc = rpr_getfp('ImGui_Key_F7')
    Key_F7.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F7, 'cache'):
    Key_F7.cache = Key_F7.func()
  return Key_F7.cache

def Key_F8():
  if not hasattr(Key_F8, 'func'):
    proc = rpr_getfp('ImGui_Key_F8')
    Key_F8.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F8, 'cache'):
    Key_F8.cache = Key_F8.func()
  return Key_F8.cache

def Key_F9():
  if not hasattr(Key_F9, 'func'):
    proc = rpr_getfp('ImGui_Key_F9')
    Key_F9.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_F9, 'cache'):
    Key_F9.cache = Key_F9.func()
  return Key_F9.cache

def Key_G():
  if not hasattr(Key_G, 'func'):
    proc = rpr_getfp('ImGui_Key_G')
    Key_G.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_G, 'cache'):
    Key_G.cache = Key_G.func()
  return Key_G.cache

def Key_GraveAccent():
  if not hasattr(Key_GraveAccent, 'func'):
    proc = rpr_getfp('ImGui_Key_GraveAccent')
    Key_GraveAccent.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_GraveAccent, 'cache'):
    Key_GraveAccent.cache = Key_GraveAccent.func()
  return Key_GraveAccent.cache

def Key_H():
  if not hasattr(Key_H, 'func'):
    proc = rpr_getfp('ImGui_Key_H')
    Key_H.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_H, 'cache'):
    Key_H.cache = Key_H.func()
  return Key_H.cache

def Key_Home():
  if not hasattr(Key_Home, 'func'):
    proc = rpr_getfp('ImGui_Key_Home')
    Key_Home.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Home, 'cache'):
    Key_Home.cache = Key_Home.func()
  return Key_Home.cache

def Key_I():
  if not hasattr(Key_I, 'func'):
    proc = rpr_getfp('ImGui_Key_I')
    Key_I.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_I, 'cache'):
    Key_I.cache = Key_I.func()
  return Key_I.cache

def Key_Insert():
  if not hasattr(Key_Insert, 'func'):
    proc = rpr_getfp('ImGui_Key_Insert')
    Key_Insert.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Insert, 'cache'):
    Key_Insert.cache = Key_Insert.func()
  return Key_Insert.cache

def Key_J():
  if not hasattr(Key_J, 'func'):
    proc = rpr_getfp('ImGui_Key_J')
    Key_J.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_J, 'cache'):
    Key_J.cache = Key_J.func()
  return Key_J.cache

def Key_K():
  if not hasattr(Key_K, 'func'):
    proc = rpr_getfp('ImGui_Key_K')
    Key_K.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_K, 'cache'):
    Key_K.cache = Key_K.func()
  return Key_K.cache

def Key_Keypad0():
  if not hasattr(Key_Keypad0, 'func'):
    proc = rpr_getfp('ImGui_Key_Keypad0')
    Key_Keypad0.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Keypad0, 'cache'):
    Key_Keypad0.cache = Key_Keypad0.func()
  return Key_Keypad0.cache

def Key_Keypad1():
  if not hasattr(Key_Keypad1, 'func'):
    proc = rpr_getfp('ImGui_Key_Keypad1')
    Key_Keypad1.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Keypad1, 'cache'):
    Key_Keypad1.cache = Key_Keypad1.func()
  return Key_Keypad1.cache

def Key_Keypad2():
  if not hasattr(Key_Keypad2, 'func'):
    proc = rpr_getfp('ImGui_Key_Keypad2')
    Key_Keypad2.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Keypad2, 'cache'):
    Key_Keypad2.cache = Key_Keypad2.func()
  return Key_Keypad2.cache

def Key_Keypad3():
  if not hasattr(Key_Keypad3, 'func'):
    proc = rpr_getfp('ImGui_Key_Keypad3')
    Key_Keypad3.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Keypad3, 'cache'):
    Key_Keypad3.cache = Key_Keypad3.func()
  return Key_Keypad3.cache

def Key_Keypad4():
  if not hasattr(Key_Keypad4, 'func'):
    proc = rpr_getfp('ImGui_Key_Keypad4')
    Key_Keypad4.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Keypad4, 'cache'):
    Key_Keypad4.cache = Key_Keypad4.func()
  return Key_Keypad4.cache

def Key_Keypad5():
  if not hasattr(Key_Keypad5, 'func'):
    proc = rpr_getfp('ImGui_Key_Keypad5')
    Key_Keypad5.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Keypad5, 'cache'):
    Key_Keypad5.cache = Key_Keypad5.func()
  return Key_Keypad5.cache

def Key_Keypad6():
  if not hasattr(Key_Keypad6, 'func'):
    proc = rpr_getfp('ImGui_Key_Keypad6')
    Key_Keypad6.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Keypad6, 'cache'):
    Key_Keypad6.cache = Key_Keypad6.func()
  return Key_Keypad6.cache

def Key_Keypad7():
  if not hasattr(Key_Keypad7, 'func'):
    proc = rpr_getfp('ImGui_Key_Keypad7')
    Key_Keypad7.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Keypad7, 'cache'):
    Key_Keypad7.cache = Key_Keypad7.func()
  return Key_Keypad7.cache

def Key_Keypad8():
  if not hasattr(Key_Keypad8, 'func'):
    proc = rpr_getfp('ImGui_Key_Keypad8')
    Key_Keypad8.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Keypad8, 'cache'):
    Key_Keypad8.cache = Key_Keypad8.func()
  return Key_Keypad8.cache

def Key_Keypad9():
  if not hasattr(Key_Keypad9, 'func'):
    proc = rpr_getfp('ImGui_Key_Keypad9')
    Key_Keypad9.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Keypad9, 'cache'):
    Key_Keypad9.cache = Key_Keypad9.func()
  return Key_Keypad9.cache

def Key_KeypadAdd():
  if not hasattr(Key_KeypadAdd, 'func'):
    proc = rpr_getfp('ImGui_Key_KeypadAdd')
    Key_KeypadAdd.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_KeypadAdd, 'cache'):
    Key_KeypadAdd.cache = Key_KeypadAdd.func()
  return Key_KeypadAdd.cache

def Key_KeypadDecimal():
  if not hasattr(Key_KeypadDecimal, 'func'):
    proc = rpr_getfp('ImGui_Key_KeypadDecimal')
    Key_KeypadDecimal.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_KeypadDecimal, 'cache'):
    Key_KeypadDecimal.cache = Key_KeypadDecimal.func()
  return Key_KeypadDecimal.cache

def Key_KeypadDivide():
  if not hasattr(Key_KeypadDivide, 'func'):
    proc = rpr_getfp('ImGui_Key_KeypadDivide')
    Key_KeypadDivide.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_KeypadDivide, 'cache'):
    Key_KeypadDivide.cache = Key_KeypadDivide.func()
  return Key_KeypadDivide.cache

def Key_KeypadEnter():
  if not hasattr(Key_KeypadEnter, 'func'):
    proc = rpr_getfp('ImGui_Key_KeypadEnter')
    Key_KeypadEnter.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_KeypadEnter, 'cache'):
    Key_KeypadEnter.cache = Key_KeypadEnter.func()
  return Key_KeypadEnter.cache

def Key_KeypadEqual():
  if not hasattr(Key_KeypadEqual, 'func'):
    proc = rpr_getfp('ImGui_Key_KeypadEqual')
    Key_KeypadEqual.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_KeypadEqual, 'cache'):
    Key_KeypadEqual.cache = Key_KeypadEqual.func()
  return Key_KeypadEqual.cache

def Key_KeypadMultiply():
  if not hasattr(Key_KeypadMultiply, 'func'):
    proc = rpr_getfp('ImGui_Key_KeypadMultiply')
    Key_KeypadMultiply.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_KeypadMultiply, 'cache'):
    Key_KeypadMultiply.cache = Key_KeypadMultiply.func()
  return Key_KeypadMultiply.cache

def Key_KeypadSubtract():
  if not hasattr(Key_KeypadSubtract, 'func'):
    proc = rpr_getfp('ImGui_Key_KeypadSubtract')
    Key_KeypadSubtract.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_KeypadSubtract, 'cache'):
    Key_KeypadSubtract.cache = Key_KeypadSubtract.func()
  return Key_KeypadSubtract.cache

def Key_L():
  if not hasattr(Key_L, 'func'):
    proc = rpr_getfp('ImGui_Key_L')
    Key_L.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_L, 'cache'):
    Key_L.cache = Key_L.func()
  return Key_L.cache

def Key_LeftAlt():
  if not hasattr(Key_LeftAlt, 'func'):
    proc = rpr_getfp('ImGui_Key_LeftAlt')
    Key_LeftAlt.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_LeftAlt, 'cache'):
    Key_LeftAlt.cache = Key_LeftAlt.func()
  return Key_LeftAlt.cache

def Key_LeftArrow():
  if not hasattr(Key_LeftArrow, 'func'):
    proc = rpr_getfp('ImGui_Key_LeftArrow')
    Key_LeftArrow.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_LeftArrow, 'cache'):
    Key_LeftArrow.cache = Key_LeftArrow.func()
  return Key_LeftArrow.cache

def Key_LeftBracket():
  if not hasattr(Key_LeftBracket, 'func'):
    proc = rpr_getfp('ImGui_Key_LeftBracket')
    Key_LeftBracket.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_LeftBracket, 'cache'):
    Key_LeftBracket.cache = Key_LeftBracket.func()
  return Key_LeftBracket.cache

def Key_LeftCtrl():
  if not hasattr(Key_LeftCtrl, 'func'):
    proc = rpr_getfp('ImGui_Key_LeftCtrl')
    Key_LeftCtrl.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_LeftCtrl, 'cache'):
    Key_LeftCtrl.cache = Key_LeftCtrl.func()
  return Key_LeftCtrl.cache

def Key_LeftShift():
  if not hasattr(Key_LeftShift, 'func'):
    proc = rpr_getfp('ImGui_Key_LeftShift')
    Key_LeftShift.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_LeftShift, 'cache'):
    Key_LeftShift.cache = Key_LeftShift.func()
  return Key_LeftShift.cache

def Key_LeftSuper():
  if not hasattr(Key_LeftSuper, 'func'):
    proc = rpr_getfp('ImGui_Key_LeftSuper')
    Key_LeftSuper.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_LeftSuper, 'cache'):
    Key_LeftSuper.cache = Key_LeftSuper.func()
  return Key_LeftSuper.cache

def Key_M():
  if not hasattr(Key_M, 'func'):
    proc = rpr_getfp('ImGui_Key_M')
    Key_M.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_M, 'cache'):
    Key_M.cache = Key_M.func()
  return Key_M.cache

def Key_Menu():
  if not hasattr(Key_Menu, 'func'):
    proc = rpr_getfp('ImGui_Key_Menu')
    Key_Menu.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Menu, 'cache'):
    Key_Menu.cache = Key_Menu.func()
  return Key_Menu.cache

def Key_Minus():
  if not hasattr(Key_Minus, 'func'):
    proc = rpr_getfp('ImGui_Key_Minus')
    Key_Minus.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Minus, 'cache'):
    Key_Minus.cache = Key_Minus.func()
  return Key_Minus.cache

def Key_N():
  if not hasattr(Key_N, 'func'):
    proc = rpr_getfp('ImGui_Key_N')
    Key_N.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_N, 'cache'):
    Key_N.cache = Key_N.func()
  return Key_N.cache

def Key_NumLock():
  if not hasattr(Key_NumLock, 'func'):
    proc = rpr_getfp('ImGui_Key_NumLock')
    Key_NumLock.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_NumLock, 'cache'):
    Key_NumLock.cache = Key_NumLock.func()
  return Key_NumLock.cache

def Key_O():
  if not hasattr(Key_O, 'func'):
    proc = rpr_getfp('ImGui_Key_O')
    Key_O.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_O, 'cache'):
    Key_O.cache = Key_O.func()
  return Key_O.cache

def Key_Oem102():
  if not hasattr(Key_Oem102, 'func'):
    proc = rpr_getfp('ImGui_Key_Oem102')
    Key_Oem102.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Oem102, 'cache'):
    Key_Oem102.cache = Key_Oem102.func()
  return Key_Oem102.cache

def Key_P():
  if not hasattr(Key_P, 'func'):
    proc = rpr_getfp('ImGui_Key_P')
    Key_P.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_P, 'cache'):
    Key_P.cache = Key_P.func()
  return Key_P.cache

def Key_PageDown():
  if not hasattr(Key_PageDown, 'func'):
    proc = rpr_getfp('ImGui_Key_PageDown')
    Key_PageDown.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_PageDown, 'cache'):
    Key_PageDown.cache = Key_PageDown.func()
  return Key_PageDown.cache

def Key_PageUp():
  if not hasattr(Key_PageUp, 'func'):
    proc = rpr_getfp('ImGui_Key_PageUp')
    Key_PageUp.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_PageUp, 'cache'):
    Key_PageUp.cache = Key_PageUp.func()
  return Key_PageUp.cache

def Key_Pause():
  if not hasattr(Key_Pause, 'func'):
    proc = rpr_getfp('ImGui_Key_Pause')
    Key_Pause.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Pause, 'cache'):
    Key_Pause.cache = Key_Pause.func()
  return Key_Pause.cache

def Key_Period():
  if not hasattr(Key_Period, 'func'):
    proc = rpr_getfp('ImGui_Key_Period')
    Key_Period.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Period, 'cache'):
    Key_Period.cache = Key_Period.func()
  return Key_Period.cache

def Key_PrintScreen():
  if not hasattr(Key_PrintScreen, 'func'):
    proc = rpr_getfp('ImGui_Key_PrintScreen')
    Key_PrintScreen.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_PrintScreen, 'cache'):
    Key_PrintScreen.cache = Key_PrintScreen.func()
  return Key_PrintScreen.cache

def Key_Q():
  if not hasattr(Key_Q, 'func'):
    proc = rpr_getfp('ImGui_Key_Q')
    Key_Q.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Q, 'cache'):
    Key_Q.cache = Key_Q.func()
  return Key_Q.cache

def Key_R():
  if not hasattr(Key_R, 'func'):
    proc = rpr_getfp('ImGui_Key_R')
    Key_R.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_R, 'cache'):
    Key_R.cache = Key_R.func()
  return Key_R.cache

def Key_RightAlt():
  if not hasattr(Key_RightAlt, 'func'):
    proc = rpr_getfp('ImGui_Key_RightAlt')
    Key_RightAlt.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_RightAlt, 'cache'):
    Key_RightAlt.cache = Key_RightAlt.func()
  return Key_RightAlt.cache

def Key_RightArrow():
  if not hasattr(Key_RightArrow, 'func'):
    proc = rpr_getfp('ImGui_Key_RightArrow')
    Key_RightArrow.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_RightArrow, 'cache'):
    Key_RightArrow.cache = Key_RightArrow.func()
  return Key_RightArrow.cache

def Key_RightBracket():
  if not hasattr(Key_RightBracket, 'func'):
    proc = rpr_getfp('ImGui_Key_RightBracket')
    Key_RightBracket.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_RightBracket, 'cache'):
    Key_RightBracket.cache = Key_RightBracket.func()
  return Key_RightBracket.cache

def Key_RightCtrl():
  if not hasattr(Key_RightCtrl, 'func'):
    proc = rpr_getfp('ImGui_Key_RightCtrl')
    Key_RightCtrl.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_RightCtrl, 'cache'):
    Key_RightCtrl.cache = Key_RightCtrl.func()
  return Key_RightCtrl.cache

def Key_RightShift():
  if not hasattr(Key_RightShift, 'func'):
    proc = rpr_getfp('ImGui_Key_RightShift')
    Key_RightShift.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_RightShift, 'cache'):
    Key_RightShift.cache = Key_RightShift.func()
  return Key_RightShift.cache

def Key_RightSuper():
  if not hasattr(Key_RightSuper, 'func'):
    proc = rpr_getfp('ImGui_Key_RightSuper')
    Key_RightSuper.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_RightSuper, 'cache'):
    Key_RightSuper.cache = Key_RightSuper.func()
  return Key_RightSuper.cache

def Key_S():
  if not hasattr(Key_S, 'func'):
    proc = rpr_getfp('ImGui_Key_S')
    Key_S.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_S, 'cache'):
    Key_S.cache = Key_S.func()
  return Key_S.cache

def Key_ScrollLock():
  if not hasattr(Key_ScrollLock, 'func'):
    proc = rpr_getfp('ImGui_Key_ScrollLock')
    Key_ScrollLock.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_ScrollLock, 'cache'):
    Key_ScrollLock.cache = Key_ScrollLock.func()
  return Key_ScrollLock.cache

def Key_Semicolon():
  if not hasattr(Key_Semicolon, 'func'):
    proc = rpr_getfp('ImGui_Key_Semicolon')
    Key_Semicolon.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Semicolon, 'cache'):
    Key_Semicolon.cache = Key_Semicolon.func()
  return Key_Semicolon.cache

def Key_Slash():
  if not hasattr(Key_Slash, 'func'):
    proc = rpr_getfp('ImGui_Key_Slash')
    Key_Slash.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Slash, 'cache'):
    Key_Slash.cache = Key_Slash.func()
  return Key_Slash.cache

def Key_Space():
  if not hasattr(Key_Space, 'func'):
    proc = rpr_getfp('ImGui_Key_Space')
    Key_Space.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Space, 'cache'):
    Key_Space.cache = Key_Space.func()
  return Key_Space.cache

def Key_T():
  if not hasattr(Key_T, 'func'):
    proc = rpr_getfp('ImGui_Key_T')
    Key_T.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_T, 'cache'):
    Key_T.cache = Key_T.func()
  return Key_T.cache

def Key_Tab():
  if not hasattr(Key_Tab, 'func'):
    proc = rpr_getfp('ImGui_Key_Tab')
    Key_Tab.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Tab, 'cache'):
    Key_Tab.cache = Key_Tab.func()
  return Key_Tab.cache

def Key_U():
  if not hasattr(Key_U, 'func'):
    proc = rpr_getfp('ImGui_Key_U')
    Key_U.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_U, 'cache'):
    Key_U.cache = Key_U.func()
  return Key_U.cache

def Key_UpArrow():
  if not hasattr(Key_UpArrow, 'func'):
    proc = rpr_getfp('ImGui_Key_UpArrow')
    Key_UpArrow.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_UpArrow, 'cache'):
    Key_UpArrow.cache = Key_UpArrow.func()
  return Key_UpArrow.cache

def Key_V():
  if not hasattr(Key_V, 'func'):
    proc = rpr_getfp('ImGui_Key_V')
    Key_V.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_V, 'cache'):
    Key_V.cache = Key_V.func()
  return Key_V.cache

def Key_W():
  if not hasattr(Key_W, 'func'):
    proc = rpr_getfp('ImGui_Key_W')
    Key_W.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_W, 'cache'):
    Key_W.cache = Key_W.func()
  return Key_W.cache

def Key_X():
  if not hasattr(Key_X, 'func'):
    proc = rpr_getfp('ImGui_Key_X')
    Key_X.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_X, 'cache'):
    Key_X.cache = Key_X.func()
  return Key_X.cache

def Key_Y():
  if not hasattr(Key_Y, 'func'):
    proc = rpr_getfp('ImGui_Key_Y')
    Key_Y.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Y, 'cache'):
    Key_Y.cache = Key_Y.func()
  return Key_Y.cache

def Key_Z():
  if not hasattr(Key_Z, 'func'):
    proc = rpr_getfp('ImGui_Key_Z')
    Key_Z.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_Z, 'cache'):
    Key_Z.cache = Key_Z.func()
  return Key_Z.cache

def Mod_Alt():
  if not hasattr(Mod_Alt, 'func'):
    proc = rpr_getfp('ImGui_Mod_Alt')
    Mod_Alt.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Mod_Alt, 'cache'):
    Mod_Alt.cache = Mod_Alt.func()
  return Mod_Alt.cache

def Mod_Ctrl():
  if not hasattr(Mod_Ctrl, 'func'):
    proc = rpr_getfp('ImGui_Mod_Ctrl')
    Mod_Ctrl.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Mod_Ctrl, 'cache'):
    Mod_Ctrl.cache = Mod_Ctrl.func()
  return Mod_Ctrl.cache

def Mod_None():
  if not hasattr(Mod_None, 'func'):
    proc = rpr_getfp('ImGui_Mod_None')
    Mod_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Mod_None, 'cache'):
    Mod_None.cache = Mod_None.func()
  return Mod_None.cache

def Mod_Shift():
  if not hasattr(Mod_Shift, 'func'):
    proc = rpr_getfp('ImGui_Mod_Shift')
    Mod_Shift.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Mod_Shift, 'cache'):
    Mod_Shift.cache = Mod_Shift.func()
  return Mod_Shift.cache

def Mod_Super():
  if not hasattr(Mod_Super, 'func'):
    proc = rpr_getfp('ImGui_Mod_Super')
    Mod_Super.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Mod_Super, 'cache'):
    Mod_Super.cache = Mod_Super.func()
  return Mod_Super.cache

def Key_MouseLeft():
  if not hasattr(Key_MouseLeft, 'func'):
    proc = rpr_getfp('ImGui_Key_MouseLeft')
    Key_MouseLeft.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_MouseLeft, 'cache'):
    Key_MouseLeft.cache = Key_MouseLeft.func()
  return Key_MouseLeft.cache

def Key_MouseMiddle():
  if not hasattr(Key_MouseMiddle, 'func'):
    proc = rpr_getfp('ImGui_Key_MouseMiddle')
    Key_MouseMiddle.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_MouseMiddle, 'cache'):
    Key_MouseMiddle.cache = Key_MouseMiddle.func()
  return Key_MouseMiddle.cache

def Key_MouseRight():
  if not hasattr(Key_MouseRight, 'func'):
    proc = rpr_getfp('ImGui_Key_MouseRight')
    Key_MouseRight.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_MouseRight, 'cache'):
    Key_MouseRight.cache = Key_MouseRight.func()
  return Key_MouseRight.cache

def Key_MouseWheelX():
  if not hasattr(Key_MouseWheelX, 'func'):
    proc = rpr_getfp('ImGui_Key_MouseWheelX')
    Key_MouseWheelX.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_MouseWheelX, 'cache'):
    Key_MouseWheelX.cache = Key_MouseWheelX.func()
  return Key_MouseWheelX.cache

def Key_MouseWheelY():
  if not hasattr(Key_MouseWheelY, 'func'):
    proc = rpr_getfp('ImGui_Key_MouseWheelY')
    Key_MouseWheelY.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_MouseWheelY, 'cache'):
    Key_MouseWheelY.cache = Key_MouseWheelY.func()
  return Key_MouseWheelY.cache

def Key_MouseX1():
  if not hasattr(Key_MouseX1, 'func'):
    proc = rpr_getfp('ImGui_Key_MouseX1')
    Key_MouseX1.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_MouseX1, 'cache'):
    Key_MouseX1.cache = Key_MouseX1.func()
  return Key_MouseX1.cache

def Key_MouseX2():
  if not hasattr(Key_MouseX2, 'func'):
    proc = rpr_getfp('ImGui_Key_MouseX2')
    Key_MouseX2.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Key_MouseX2, 'cache'):
    Key_MouseX2.cache = Key_MouseX2.func()
  return Key_MouseX2.cache

def GetMouseClickedCount(ctx, button):
  if not hasattr(GetMouseClickedCount, 'func'):
    proc = rpr_getfp('ImGui_GetMouseClickedCount')
    GetMouseClickedCount.func = CFUNCTYPE(c_int, c_void_p, c_int)(proc)
  args = (c_void_p(ctx), c_int(button))
  rval = GetMouseClickedCount.func(args[0], args[1])
  return rval

def GetMouseClickedPos(ctx, button):
  if not hasattr(GetMouseClickedPos, 'func'):
    proc = rpr_getfp('ImGui_GetMouseClickedPos')
    GetMouseClickedPos.func = CFUNCTYPE(None, c_void_p, c_int, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(button), c_double(0), c_double(0))
  GetMouseClickedPos.func(args[0], args[1], byref(args[2]), byref(args[3]))
  return float(args[2].value), float(args[3].value)

def GetMouseDelta(ctx):
  if not hasattr(GetMouseDelta, 'func'):
    proc = rpr_getfp('ImGui_GetMouseDelta')
    GetMouseDelta.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(0), c_double(0))
  GetMouseDelta.func(args[0], byref(args[1]), byref(args[2]))
  return float(args[1].value), float(args[2].value)

def GetMouseDownDuration(ctx, button):
  if not hasattr(GetMouseDownDuration, 'func'):
    proc = rpr_getfp('ImGui_GetMouseDownDuration')
    GetMouseDownDuration.func = CFUNCTYPE(c_double, c_void_p, c_int)(proc)
  args = (c_void_p(ctx), c_int(button))
  rval = GetMouseDownDuration.func(args[0], args[1])
  return rval

def GetMouseDragDelta(ctx, buttonInOptional = None, lock_thresholdInOptional = None):
  if not hasattr(GetMouseDragDelta, 'func'):
    proc = rpr_getfp('ImGui_GetMouseDragDelta')
    GetMouseDragDelta.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(0), c_double(0), c_int(buttonInOptional) if buttonInOptional != None else None, c_double(lock_thresholdInOptional) if lock_thresholdInOptional != None else None)
  GetMouseDragDelta.func(args[0], byref(args[1]), byref(args[2]), byref(args[3]) if args[3] != None else None, byref(args[4]) if args[4] != None else None)
  return float(args[1].value), float(args[2].value)

def GetMousePos(ctx):
  if not hasattr(GetMousePos, 'func'):
    proc = rpr_getfp('ImGui_GetMousePos')
    GetMousePos.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(0), c_double(0))
  GetMousePos.func(args[0], byref(args[1]), byref(args[2]))
  return float(args[1].value), float(args[2].value)

def GetMousePosOnOpeningCurrentPopup(ctx):
  if not hasattr(GetMousePosOnOpeningCurrentPopup, 'func'):
    proc = rpr_getfp('ImGui_GetMousePosOnOpeningCurrentPopup')
    GetMousePosOnOpeningCurrentPopup.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(0), c_double(0))
  GetMousePosOnOpeningCurrentPopup.func(args[0], byref(args[1]), byref(args[2]))
  return float(args[1].value), float(args[2].value)

def GetMouseWheel(ctx):
  if not hasattr(GetMouseWheel, 'func'):
    proc = rpr_getfp('ImGui_GetMouseWheel')
    GetMouseWheel.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(0), c_double(0))
  GetMouseWheel.func(args[0], byref(args[1]), byref(args[2]))
  return float(args[1].value), float(args[2].value)

def IsAnyMouseDown(ctx):
  if not hasattr(IsAnyMouseDown, 'func'):
    proc = rpr_getfp('ImGui_IsAnyMouseDown')
    IsAnyMouseDown.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = IsAnyMouseDown.func(args[0])
  return rval

def IsMouseClicked(ctx, button, repeatInOptional = None):
  if not hasattr(IsMouseClicked, 'func'):
    proc = rpr_getfp('ImGui_IsMouseClicked')
    IsMouseClicked.func = CFUNCTYPE(c_bool, c_void_p, c_int, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(button), c_bool(repeatInOptional) if repeatInOptional != None else None)
  rval = IsMouseClicked.func(args[0], args[1], byref(args[2]) if args[2] != None else None)
  return rval

def IsMouseDoubleClicked(ctx, button):
  if not hasattr(IsMouseDoubleClicked, 'func'):
    proc = rpr_getfp('ImGui_IsMouseDoubleClicked')
    IsMouseDoubleClicked.func = CFUNCTYPE(c_bool, c_void_p, c_int)(proc)
  args = (c_void_p(ctx), c_int(button))
  rval = IsMouseDoubleClicked.func(args[0], args[1])
  return rval

def IsMouseDown(ctx, button):
  if not hasattr(IsMouseDown, 'func'):
    proc = rpr_getfp('ImGui_IsMouseDown')
    IsMouseDown.func = CFUNCTYPE(c_bool, c_void_p, c_int)(proc)
  args = (c_void_p(ctx), c_int(button))
  rval = IsMouseDown.func(args[0], args[1])
  return rval

def IsMouseDragging(ctx, button, lock_thresholdInOptional = None):
  if not hasattr(IsMouseDragging, 'func'):
    proc = rpr_getfp('ImGui_IsMouseDragging')
    IsMouseDragging.func = CFUNCTYPE(c_bool, c_void_p, c_int, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(button), c_double(lock_thresholdInOptional) if lock_thresholdInOptional != None else None)
  rval = IsMouseDragging.func(args[0], args[1], byref(args[2]) if args[2] != None else None)
  return rval

def IsMouseHoveringRect(ctx, r_min_x, r_min_y, r_max_x, r_max_y, clipInOptional = None):
  if not hasattr(IsMouseHoveringRect, 'func'):
    proc = rpr_getfp('ImGui_IsMouseHoveringRect')
    IsMouseHoveringRect.func = CFUNCTYPE(c_bool, c_void_p, c_double, c_double, c_double, c_double, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(r_min_x), c_double(r_min_y), c_double(r_max_x), c_double(r_max_y), c_bool(clipInOptional) if clipInOptional != None else None)
  rval = IsMouseHoveringRect.func(args[0], args[1], args[2], args[3], args[4], byref(args[5]) if args[5] != None else None)
  return rval

def IsMousePosValid(ctx, mouse_pos_xInOptional = None, mouse_pos_yInOptional = None):
  if not hasattr(IsMousePosValid, 'func'):
    proc = rpr_getfp('ImGui_IsMousePosValid')
    IsMousePosValid.func = CFUNCTYPE(c_bool, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(mouse_pos_xInOptional) if mouse_pos_xInOptional != None else None, c_double(mouse_pos_yInOptional) if mouse_pos_yInOptional != None else None)
  rval = IsMousePosValid.func(args[0], byref(args[1]) if args[1] != None else None, byref(args[2]) if args[2] != None else None)
  return rval

def IsMouseReleased(ctx, button):
  if not hasattr(IsMouseReleased, 'func'):
    proc = rpr_getfp('ImGui_IsMouseReleased')
    IsMouseReleased.func = CFUNCTYPE(c_bool, c_void_p, c_int)(proc)
  args = (c_void_p(ctx), c_int(button))
  rval = IsMouseReleased.func(args[0], args[1])
  return rval

def IsMouseReleasedWithDelay(ctx, button, delay):
  if not hasattr(IsMouseReleasedWithDelay, 'func'):
    proc = rpr_getfp('ImGui_IsMouseReleasedWithDelay')
    IsMouseReleasedWithDelay.func = CFUNCTYPE(c_bool, c_void_p, c_int, c_double)(proc)
  args = (c_void_p(ctx), c_int(button), c_double(delay))
  rval = IsMouseReleasedWithDelay.func(args[0], args[1], args[2])
  return rval

def MouseButton_Left():
  if not hasattr(MouseButton_Left, 'func'):
    proc = rpr_getfp('ImGui_MouseButton_Left')
    MouseButton_Left.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(MouseButton_Left, 'cache'):
    MouseButton_Left.cache = MouseButton_Left.func()
  return MouseButton_Left.cache

def MouseButton_Middle():
  if not hasattr(MouseButton_Middle, 'func'):
    proc = rpr_getfp('ImGui_MouseButton_Middle')
    MouseButton_Middle.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(MouseButton_Middle, 'cache'):
    MouseButton_Middle.cache = MouseButton_Middle.func()
  return MouseButton_Middle.cache

def MouseButton_Right():
  if not hasattr(MouseButton_Right, 'func'):
    proc = rpr_getfp('ImGui_MouseButton_Right')
    MouseButton_Right.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(MouseButton_Right, 'cache'):
    MouseButton_Right.cache = MouseButton_Right.func()
  return MouseButton_Right.cache

def ResetMouseDragDelta(ctx, buttonInOptional = None):
  if not hasattr(ResetMouseDragDelta, 'func'):
    proc = rpr_getfp('ImGui_ResetMouseDragDelta')
    ResetMouseDragDelta.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(buttonInOptional) if buttonInOptional != None else None)
  ResetMouseDragDelta.func(args[0], byref(args[1]) if args[1] != None else None)

def GetMouseCursor(ctx):
  if not hasattr(GetMouseCursor, 'func'):
    proc = rpr_getfp('ImGui_GetMouseCursor')
    GetMouseCursor.func = CFUNCTYPE(c_int, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetMouseCursor.func(args[0])
  return rval

def MouseCursor_Arrow():
  if not hasattr(MouseCursor_Arrow, 'func'):
    proc = rpr_getfp('ImGui_MouseCursor_Arrow')
    MouseCursor_Arrow.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(MouseCursor_Arrow, 'cache'):
    MouseCursor_Arrow.cache = MouseCursor_Arrow.func()
  return MouseCursor_Arrow.cache

def MouseCursor_Hand():
  if not hasattr(MouseCursor_Hand, 'func'):
    proc = rpr_getfp('ImGui_MouseCursor_Hand')
    MouseCursor_Hand.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(MouseCursor_Hand, 'cache'):
    MouseCursor_Hand.cache = MouseCursor_Hand.func()
  return MouseCursor_Hand.cache

def MouseCursor_None():
  if not hasattr(MouseCursor_None, 'func'):
    proc = rpr_getfp('ImGui_MouseCursor_None')
    MouseCursor_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(MouseCursor_None, 'cache'):
    MouseCursor_None.cache = MouseCursor_None.func()
  return MouseCursor_None.cache

def MouseCursor_NotAllowed():
  if not hasattr(MouseCursor_NotAllowed, 'func'):
    proc = rpr_getfp('ImGui_MouseCursor_NotAllowed')
    MouseCursor_NotAllowed.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(MouseCursor_NotAllowed, 'cache'):
    MouseCursor_NotAllowed.cache = MouseCursor_NotAllowed.func()
  return MouseCursor_NotAllowed.cache

def MouseCursor_Progress():
  if not hasattr(MouseCursor_Progress, 'func'):
    proc = rpr_getfp('ImGui_MouseCursor_Progress')
    MouseCursor_Progress.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(MouseCursor_Progress, 'cache'):
    MouseCursor_Progress.cache = MouseCursor_Progress.func()
  return MouseCursor_Progress.cache

def MouseCursor_ResizeAll():
  if not hasattr(MouseCursor_ResizeAll, 'func'):
    proc = rpr_getfp('ImGui_MouseCursor_ResizeAll')
    MouseCursor_ResizeAll.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(MouseCursor_ResizeAll, 'cache'):
    MouseCursor_ResizeAll.cache = MouseCursor_ResizeAll.func()
  return MouseCursor_ResizeAll.cache

def MouseCursor_ResizeEW():
  if not hasattr(MouseCursor_ResizeEW, 'func'):
    proc = rpr_getfp('ImGui_MouseCursor_ResizeEW')
    MouseCursor_ResizeEW.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(MouseCursor_ResizeEW, 'cache'):
    MouseCursor_ResizeEW.cache = MouseCursor_ResizeEW.func()
  return MouseCursor_ResizeEW.cache

def MouseCursor_ResizeNESW():
  if not hasattr(MouseCursor_ResizeNESW, 'func'):
    proc = rpr_getfp('ImGui_MouseCursor_ResizeNESW')
    MouseCursor_ResizeNESW.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(MouseCursor_ResizeNESW, 'cache'):
    MouseCursor_ResizeNESW.cache = MouseCursor_ResizeNESW.func()
  return MouseCursor_ResizeNESW.cache

def MouseCursor_ResizeNS():
  if not hasattr(MouseCursor_ResizeNS, 'func'):
    proc = rpr_getfp('ImGui_MouseCursor_ResizeNS')
    MouseCursor_ResizeNS.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(MouseCursor_ResizeNS, 'cache'):
    MouseCursor_ResizeNS.cache = MouseCursor_ResizeNS.func()
  return MouseCursor_ResizeNS.cache

def MouseCursor_ResizeNWSE():
  if not hasattr(MouseCursor_ResizeNWSE, 'func'):
    proc = rpr_getfp('ImGui_MouseCursor_ResizeNWSE')
    MouseCursor_ResizeNWSE.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(MouseCursor_ResizeNWSE, 'cache'):
    MouseCursor_ResizeNWSE.cache = MouseCursor_ResizeNWSE.func()
  return MouseCursor_ResizeNWSE.cache

def MouseCursor_TextInput():
  if not hasattr(MouseCursor_TextInput, 'func'):
    proc = rpr_getfp('ImGui_MouseCursor_TextInput')
    MouseCursor_TextInput.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(MouseCursor_TextInput, 'cache'):
    MouseCursor_TextInput.cache = MouseCursor_TextInput.func()
  return MouseCursor_TextInput.cache

def MouseCursor_Wait():
  if not hasattr(MouseCursor_Wait, 'func'):
    proc = rpr_getfp('ImGui_MouseCursor_Wait')
    MouseCursor_Wait.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(MouseCursor_Wait, 'cache'):
    MouseCursor_Wait.cache = MouseCursor_Wait.func()
  return MouseCursor_Wait.cache

def SetMouseCursor(ctx, cursor_type):
  if not hasattr(SetMouseCursor, 'func'):
    proc = rpr_getfp('ImGui_SetMouseCursor')
    SetMouseCursor.func = CFUNCTYPE(None, c_void_p, c_int)(proc)
  args = (c_void_p(ctx), c_int(cursor_type))
  SetMouseCursor.func(args[0], args[1])

def IsKeyChordPressed(ctx, key_chord):
  if not hasattr(IsKeyChordPressed, 'func'):
    proc = rpr_getfp('ImGui_IsKeyChordPressed')
    IsKeyChordPressed.func = CFUNCTYPE(c_bool, c_void_p, c_int)(proc)
  args = (c_void_p(ctx), c_int(key_chord))
  rval = IsKeyChordPressed.func(args[0], args[1])
  return rval

def SetNextItemShortcut(ctx, key_chord, flagsInOptional = None):
  if not hasattr(SetNextItemShortcut, 'func'):
    proc = rpr_getfp('ImGui_SetNextItemShortcut')
    SetNextItemShortcut.func = CFUNCTYPE(None, c_void_p, c_int, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(key_chord), c_int(flagsInOptional) if flagsInOptional != None else None)
  SetNextItemShortcut.func(args[0], args[1], byref(args[2]) if args[2] != None else None)

def Shortcut(ctx, key_chord, flagsInOptional = None):
  if not hasattr(Shortcut, 'func'):
    proc = rpr_getfp('ImGui_Shortcut')
    Shortcut.func = CFUNCTYPE(c_bool, c_void_p, c_int, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(key_chord), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = Shortcut.func(args[0], args[1], byref(args[2]) if args[2] != None else None)
  return rval

def InputFlags_None():
  if not hasattr(InputFlags_None, 'func'):
    proc = rpr_getfp('ImGui_InputFlags_None')
    InputFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputFlags_None, 'cache'):
    InputFlags_None.cache = InputFlags_None.func()
  return InputFlags_None.cache

def InputFlags_Repeat():
  if not hasattr(InputFlags_Repeat, 'func'):
    proc = rpr_getfp('ImGui_InputFlags_Repeat')
    InputFlags_Repeat.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputFlags_Repeat, 'cache'):
    InputFlags_Repeat.cache = InputFlags_Repeat.func()
  return InputFlags_Repeat.cache

def InputFlags_RouteFromRootWindow():
  if not hasattr(InputFlags_RouteFromRootWindow, 'func'):
    proc = rpr_getfp('ImGui_InputFlags_RouteFromRootWindow')
    InputFlags_RouteFromRootWindow.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputFlags_RouteFromRootWindow, 'cache'):
    InputFlags_RouteFromRootWindow.cache = InputFlags_RouteFromRootWindow.func()
  return InputFlags_RouteFromRootWindow.cache

def InputFlags_RouteOverActive():
  if not hasattr(InputFlags_RouteOverActive, 'func'):
    proc = rpr_getfp('ImGui_InputFlags_RouteOverActive')
    InputFlags_RouteOverActive.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputFlags_RouteOverActive, 'cache'):
    InputFlags_RouteOverActive.cache = InputFlags_RouteOverActive.func()
  return InputFlags_RouteOverActive.cache

def InputFlags_RouteOverFocused():
  if not hasattr(InputFlags_RouteOverFocused, 'func'):
    proc = rpr_getfp('ImGui_InputFlags_RouteOverFocused')
    InputFlags_RouteOverFocused.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputFlags_RouteOverFocused, 'cache'):
    InputFlags_RouteOverFocused.cache = InputFlags_RouteOverFocused.func()
  return InputFlags_RouteOverFocused.cache

def InputFlags_RouteUnlessBgFocused():
  if not hasattr(InputFlags_RouteUnlessBgFocused, 'func'):
    proc = rpr_getfp('ImGui_InputFlags_RouteUnlessBgFocused')
    InputFlags_RouteUnlessBgFocused.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputFlags_RouteUnlessBgFocused, 'cache'):
    InputFlags_RouteUnlessBgFocused.cache = InputFlags_RouteUnlessBgFocused.func()
  return InputFlags_RouteUnlessBgFocused.cache

def InputFlags_Tooltip():
  if not hasattr(InputFlags_Tooltip, 'func'):
    proc = rpr_getfp('ImGui_InputFlags_Tooltip')
    InputFlags_Tooltip.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputFlags_Tooltip, 'cache'):
    InputFlags_Tooltip.cache = InputFlags_Tooltip.func()
  return InputFlags_Tooltip.cache

def InputFlags_RouteActive():
  if not hasattr(InputFlags_RouteActive, 'func'):
    proc = rpr_getfp('ImGui_InputFlags_RouteActive')
    InputFlags_RouteActive.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputFlags_RouteActive, 'cache'):
    InputFlags_RouteActive.cache = InputFlags_RouteActive.func()
  return InputFlags_RouteActive.cache

def InputFlags_RouteAlways():
  if not hasattr(InputFlags_RouteAlways, 'func'):
    proc = rpr_getfp('ImGui_InputFlags_RouteAlways')
    InputFlags_RouteAlways.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputFlags_RouteAlways, 'cache'):
    InputFlags_RouteAlways.cache = InputFlags_RouteAlways.func()
  return InputFlags_RouteAlways.cache

def InputFlags_RouteFocused():
  if not hasattr(InputFlags_RouteFocused, 'func'):
    proc = rpr_getfp('ImGui_InputFlags_RouteFocused')
    InputFlags_RouteFocused.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputFlags_RouteFocused, 'cache'):
    InputFlags_RouteFocused.cache = InputFlags_RouteFocused.func()
  return InputFlags_RouteFocused.cache

def InputFlags_RouteGlobal():
  if not hasattr(InputFlags_RouteGlobal, 'func'):
    proc = rpr_getfp('ImGui_InputFlags_RouteGlobal')
    InputFlags_RouteGlobal.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputFlags_RouteGlobal, 'cache'):
    InputFlags_RouteGlobal.cache = InputFlags_RouteGlobal.func()
  return InputFlags_RouteGlobal.cache

def BeginGroup(ctx):
  if not hasattr(BeginGroup, 'func'):
    proc = rpr_getfp('ImGui_BeginGroup')
    BeginGroup.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  BeginGroup.func(args[0])

def Dummy(ctx, size_w, size_h):
  if not hasattr(Dummy, 'func'):
    proc = rpr_getfp('ImGui_Dummy')
    Dummy.func = CFUNCTYPE(None, c_void_p, c_double, c_double)(proc)
  args = (c_void_p(ctx), c_double(size_w), c_double(size_h))
  Dummy.func(args[0], args[1], args[2])

def EndGroup(ctx):
  if not hasattr(EndGroup, 'func'):
    proc = rpr_getfp('ImGui_EndGroup')
    EndGroup.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  EndGroup.func(args[0])

def Indent(ctx, indent_wInOptional = None):
  if not hasattr(Indent, 'func'):
    proc = rpr_getfp('ImGui_Indent')
    Indent.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(indent_wInOptional) if indent_wInOptional != None else None)
  Indent.func(args[0], byref(args[1]) if args[1] != None else None)

def NewLine(ctx):
  if not hasattr(NewLine, 'func'):
    proc = rpr_getfp('ImGui_NewLine')
    NewLine.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  NewLine.func(args[0])

def SameLine(ctx, offset_from_start_xInOptional = None, spacingInOptional = None):
  if not hasattr(SameLine, 'func'):
    proc = rpr_getfp('ImGui_SameLine')
    SameLine.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(offset_from_start_xInOptional) if offset_from_start_xInOptional != None else None, c_double(spacingInOptional) if spacingInOptional != None else None)
  SameLine.func(args[0], byref(args[1]) if args[1] != None else None, byref(args[2]) if args[2] != None else None)

def Separator(ctx):
  if not hasattr(Separator, 'func'):
    proc = rpr_getfp('ImGui_Separator')
    Separator.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  Separator.func(args[0])

def SeparatorText(ctx, label):
  if not hasattr(SeparatorText, 'func'):
    proc = rpr_getfp('ImGui_SeparatorText')
    SeparatorText.func = CFUNCTYPE(None, c_void_p, c_char_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label))
  SeparatorText.func(args[0], args[1])

def Spacing(ctx):
  if not hasattr(Spacing, 'func'):
    proc = rpr_getfp('ImGui_Spacing')
    Spacing.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  Spacing.func(args[0])

def Unindent(ctx, indent_wInOptional = None):
  if not hasattr(Unindent, 'func'):
    proc = rpr_getfp('ImGui_Unindent')
    Unindent.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(indent_wInOptional) if indent_wInOptional != None else None)
  Unindent.func(args[0], byref(args[1]) if args[1] != None else None)

def IsRectVisible(ctx, size_w, size_h):
  if not hasattr(IsRectVisible, 'func'):
    proc = rpr_getfp('ImGui_IsRectVisible')
    IsRectVisible.func = CFUNCTYPE(c_bool, c_void_p, c_double, c_double)(proc)
  args = (c_void_p(ctx), c_double(size_w), c_double(size_h))
  rval = IsRectVisible.func(args[0], args[1], args[2])
  return rval

def IsRectVisibleEx(ctx, rect_min_x, rect_min_y, rect_max_x, rect_max_y):
  if not hasattr(IsRectVisibleEx, 'func'):
    proc = rpr_getfp('ImGui_IsRectVisibleEx')
    IsRectVisibleEx.func = CFUNCTYPE(c_bool, c_void_p, c_double, c_double, c_double, c_double)(proc)
  args = (c_void_p(ctx), c_double(rect_min_x), c_double(rect_min_y), c_double(rect_max_x), c_double(rect_max_y))
  rval = IsRectVisibleEx.func(args[0], args[1], args[2], args[3], args[4])
  return rval

def PopClipRect(ctx):
  if not hasattr(PopClipRect, 'func'):
    proc = rpr_getfp('ImGui_PopClipRect')
    PopClipRect.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  PopClipRect.func(args[0])

def PushClipRect(ctx, clip_rect_min_x, clip_rect_min_y, clip_rect_max_x, clip_rect_max_y, intersect_with_current_clip_rect):
  if not hasattr(PushClipRect, 'func'):
    proc = rpr_getfp('ImGui_PushClipRect')
    PushClipRect.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_double, c_bool)(proc)
  args = (c_void_p(ctx), c_double(clip_rect_min_x), c_double(clip_rect_min_y), c_double(clip_rect_max_x), c_double(clip_rect_max_y), c_bool(intersect_with_current_clip_rect))
  PushClipRect.func(args[0], args[1], args[2], args[3], args[4], args[5])

def GetContentRegionAvail(ctx):
  if not hasattr(GetContentRegionAvail, 'func'):
    proc = rpr_getfp('ImGui_GetContentRegionAvail')
    GetContentRegionAvail.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(0), c_double(0))
  GetContentRegionAvail.func(args[0], byref(args[1]), byref(args[2]))
  return float(args[1].value), float(args[2].value)

def GetCursorPos(ctx):
  if not hasattr(GetCursorPos, 'func'):
    proc = rpr_getfp('ImGui_GetCursorPos')
    GetCursorPos.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(0), c_double(0))
  GetCursorPos.func(args[0], byref(args[1]), byref(args[2]))
  return float(args[1].value), float(args[2].value)

def GetCursorPosX(ctx):
  if not hasattr(GetCursorPosX, 'func'):
    proc = rpr_getfp('ImGui_GetCursorPosX')
    GetCursorPosX.func = CFUNCTYPE(c_double, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetCursorPosX.func(args[0])
  return rval

def GetCursorPosY(ctx):
  if not hasattr(GetCursorPosY, 'func'):
    proc = rpr_getfp('ImGui_GetCursorPosY')
    GetCursorPosY.func = CFUNCTYPE(c_double, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetCursorPosY.func(args[0])
  return rval

def GetCursorScreenPos(ctx):
  if not hasattr(GetCursorScreenPos, 'func'):
    proc = rpr_getfp('ImGui_GetCursorScreenPos')
    GetCursorScreenPos.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(0), c_double(0))
  GetCursorScreenPos.func(args[0], byref(args[1]), byref(args[2]))
  return float(args[1].value), float(args[2].value)

def GetCursorStartPos(ctx):
  if not hasattr(GetCursorStartPos, 'func'):
    proc = rpr_getfp('ImGui_GetCursorStartPos')
    GetCursorStartPos.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(0), c_double(0))
  GetCursorStartPos.func(args[0], byref(args[1]), byref(args[2]))
  return float(args[1].value), float(args[2].value)

def SetCursorPos(ctx, local_pos_x, local_pos_y):
  if not hasattr(SetCursorPos, 'func'):
    proc = rpr_getfp('ImGui_SetCursorPos')
    SetCursorPos.func = CFUNCTYPE(None, c_void_p, c_double, c_double)(proc)
  args = (c_void_p(ctx), c_double(local_pos_x), c_double(local_pos_y))
  SetCursorPos.func(args[0], args[1], args[2])

def SetCursorPosX(ctx, local_x):
  if not hasattr(SetCursorPosX, 'func'):
    proc = rpr_getfp('ImGui_SetCursorPosX')
    SetCursorPosX.func = CFUNCTYPE(None, c_void_p, c_double)(proc)
  args = (c_void_p(ctx), c_double(local_x))
  SetCursorPosX.func(args[0], args[1])

def SetCursorPosY(ctx, local_y):
  if not hasattr(SetCursorPosY, 'func'):
    proc = rpr_getfp('ImGui_SetCursorPosY')
    SetCursorPosY.func = CFUNCTYPE(None, c_void_p, c_double)(proc)
  args = (c_void_p(ctx), c_double(local_y))
  SetCursorPosY.func(args[0], args[1])

def SetCursorScreenPos(ctx, pos_x, pos_y):
  if not hasattr(SetCursorScreenPos, 'func'):
    proc = rpr_getfp('ImGui_SetCursorScreenPos')
    SetCursorScreenPos.func = CFUNCTYPE(None, c_void_p, c_double, c_double)(proc)
  args = (c_void_p(ctx), c_double(pos_x), c_double(pos_y))
  SetCursorScreenPos.func(args[0], args[1], args[2])

def CreateListClipper(ctx):
  if not hasattr(CreateListClipper, 'func'):
    proc = rpr_getfp('ImGui_CreateListClipper')
    CreateListClipper.func = CFUNCTYPE(c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = CreateListClipper.func(args[0])
  return rval

def ListClipper_Begin(clipper, items_count, items_heightInOptional = None):
  if not hasattr(ListClipper_Begin, 'func'):
    proc = rpr_getfp('ImGui_ListClipper_Begin')
    ListClipper_Begin.func = CFUNCTYPE(None, c_void_p, c_int, c_void_p)(proc)
  args = (c_void_p(clipper), c_int(items_count), c_double(items_heightInOptional) if items_heightInOptional != None else None)
  ListClipper_Begin.func(args[0], args[1], byref(args[2]) if args[2] != None else None)

def ListClipper_End(clipper):
  if not hasattr(ListClipper_End, 'func'):
    proc = rpr_getfp('ImGui_ListClipper_End')
    ListClipper_End.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(clipper),)
  ListClipper_End.func(args[0])

def ListClipper_GetDisplayRange(clipper):
  if not hasattr(ListClipper_GetDisplayRange, 'func'):
    proc = rpr_getfp('ImGui_ListClipper_GetDisplayRange')
    ListClipper_GetDisplayRange.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(clipper), c_int(0), c_int(0))
  ListClipper_GetDisplayRange.func(args[0], byref(args[1]), byref(args[2]))
  return int(args[1].value), int(args[2].value)

def ListClipper_IncludeItemByIndex(clipper, item_index):
  if not hasattr(ListClipper_IncludeItemByIndex, 'func'):
    proc = rpr_getfp('ImGui_ListClipper_IncludeItemByIndex')
    ListClipper_IncludeItemByIndex.func = CFUNCTYPE(None, c_void_p, c_int)(proc)
  args = (c_void_p(clipper), c_int(item_index))
  ListClipper_IncludeItemByIndex.func(args[0], args[1])

def ListClipper_IncludeItemsByIndex(clipper, item_begin, item_end):
  if not hasattr(ListClipper_IncludeItemsByIndex, 'func'):
    proc = rpr_getfp('ImGui_ListClipper_IncludeItemsByIndex')
    ListClipper_IncludeItemsByIndex.func = CFUNCTYPE(None, c_void_p, c_int, c_int)(proc)
  args = (c_void_p(clipper), c_int(item_begin), c_int(item_end))
  ListClipper_IncludeItemsByIndex.func(args[0], args[1], args[2])

def ListClipper_SeekCursorForItem(clipper, items_count):
  if not hasattr(ListClipper_SeekCursorForItem, 'func'):
    proc = rpr_getfp('ImGui_ListClipper_SeekCursorForItem')
    ListClipper_SeekCursorForItem.func = CFUNCTYPE(None, c_void_p, c_int)(proc)
  args = (c_void_p(clipper), c_int(items_count))
  ListClipper_SeekCursorForItem.func(args[0], args[1])

def ListClipper_Step(clipper):
  if not hasattr(ListClipper_Step, 'func'):
    proc = rpr_getfp('ImGui_ListClipper_Step')
    ListClipper_Step.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(clipper),)
  rval = ListClipper_Step.func(args[0])
  return rval

def BeginMenu(ctx, label, enabledInOptional = None):
  if not hasattr(BeginMenu, 'func'):
    proc = rpr_getfp('ImGui_BeginMenu')
    BeginMenu.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_bool(enabledInOptional) if enabledInOptional != None else None)
  rval = BeginMenu.func(args[0], args[1], byref(args[2]) if args[2] != None else None)
  return rval

def BeginMenuBar(ctx):
  if not hasattr(BeginMenuBar, 'func'):
    proc = rpr_getfp('ImGui_BeginMenuBar')
    BeginMenuBar.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = BeginMenuBar.func(args[0])
  return rval

def EndMenu(ctx):
  if not hasattr(EndMenu, 'func'):
    proc = rpr_getfp('ImGui_EndMenu')
    EndMenu.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  EndMenu.func(args[0])

def EndMenuBar(ctx):
  if not hasattr(EndMenuBar, 'func'):
    proc = rpr_getfp('ImGui_EndMenuBar')
    EndMenuBar.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  EndMenuBar.func(args[0])

def MenuItem(ctx, label, shortcutInOptional = None, p_selectedInOutOptional = None, enabledInOptional = None):
  if not hasattr(MenuItem, 'func'):
    proc = rpr_getfp('ImGui_MenuItem')
    MenuItem.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_char_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), rpr_packsc(shortcutInOptional) if shortcutInOptional != None else None, c_bool(p_selectedInOutOptional) if p_selectedInOutOptional != None else None, c_bool(enabledInOptional) if enabledInOptional != None else None)
  rval = MenuItem.func(args[0], args[1], args[2], byref(args[3]) if args[3] != None else None, byref(args[4]) if args[4] != None else None)
  return rval, int(args[3].value) if p_selectedInOutOptional != None else None

def PlotHistogram(ctx, label, values, values_offsetInOptional = None, overlay_textInOptional = None, scale_minInOptional = None, scale_maxInOptional = None, graph_size_wInOptional = None, graph_size_hInOptional = None):
  if not hasattr(PlotHistogram, 'func'):
    proc = rpr_getfp('ImGui_PlotHistogram')
    PlotHistogram.func = CFUNCTYPE(None, c_void_p, c_char_p, c_void_p, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_void_p(values), c_int(values_offsetInOptional) if values_offsetInOptional != None else None, rpr_packsc(overlay_textInOptional) if overlay_textInOptional != None else None, c_double(scale_minInOptional) if scale_minInOptional != None else None, c_double(scale_maxInOptional) if scale_maxInOptional != None else None, c_double(graph_size_wInOptional) if graph_size_wInOptional != None else None, c_double(graph_size_hInOptional) if graph_size_hInOptional != None else None)
  PlotHistogram.func(args[0], args[1], args[2], byref(args[3]) if args[3] != None else None, args[4], byref(args[5]) if args[5] != None else None, byref(args[6]) if args[6] != None else None, byref(args[7]) if args[7] != None else None, byref(args[8]) if args[8] != None else None)

def PlotLines(ctx, label, values, values_offsetInOptional = None, overlay_textInOptional = None, scale_minInOptional = None, scale_maxInOptional = None, graph_size_wInOptional = None, graph_size_hInOptional = None):
  if not hasattr(PlotLines, 'func'):
    proc = rpr_getfp('ImGui_PlotLines')
    PlotLines.func = CFUNCTYPE(None, c_void_p, c_char_p, c_void_p, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_void_p(values), c_int(values_offsetInOptional) if values_offsetInOptional != None else None, rpr_packsc(overlay_textInOptional) if overlay_textInOptional != None else None, c_double(scale_minInOptional) if scale_minInOptional != None else None, c_double(scale_maxInOptional) if scale_maxInOptional != None else None, c_double(graph_size_wInOptional) if graph_size_wInOptional != None else None, c_double(graph_size_hInOptional) if graph_size_hInOptional != None else None)
  PlotLines.func(args[0], args[1], args[2], byref(args[3]) if args[3] != None else None, args[4], byref(args[5]) if args[5] != None else None, byref(args[6]) if args[6] != None else None, byref(args[7]) if args[7] != None else None, byref(args[8]) if args[8] != None else None)

def BeginPopup(ctx, str_id, flagsInOptional = None):
  if not hasattr(BeginPopup, 'func'):
    proc = rpr_getfp('ImGui_BeginPopup')
    BeginPopup.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(str_id), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = BeginPopup.func(args[0], args[1], byref(args[2]) if args[2] != None else None)
  return rval

def BeginPopupModal(ctx, name, p_openInOutOptional = None, flagsInOptional = None):
  if not hasattr(BeginPopupModal, 'func'):
    proc = rpr_getfp('ImGui_BeginPopupModal')
    BeginPopupModal.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(name), c_bool(p_openInOutOptional) if p_openInOutOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = BeginPopupModal.func(args[0], args[1], byref(args[2]) if args[2] != None else None, byref(args[3]) if args[3] != None else None)
  return rval, int(args[2].value) if p_openInOutOptional != None else None

def CloseCurrentPopup(ctx):
  if not hasattr(CloseCurrentPopup, 'func'):
    proc = rpr_getfp('ImGui_CloseCurrentPopup')
    CloseCurrentPopup.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  CloseCurrentPopup.func(args[0])

def EndPopup(ctx):
  if not hasattr(EndPopup, 'func'):
    proc = rpr_getfp('ImGui_EndPopup')
    EndPopup.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  EndPopup.func(args[0])

def IsPopupOpen(ctx, str_id, flagsInOptional = None):
  if not hasattr(IsPopupOpen, 'func'):
    proc = rpr_getfp('ImGui_IsPopupOpen')
    IsPopupOpen.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(str_id), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = IsPopupOpen.func(args[0], args[1], byref(args[2]) if args[2] != None else None)
  return rval

def OpenPopup(ctx, str_id, popup_flagsInOptional = None):
  if not hasattr(OpenPopup, 'func'):
    proc = rpr_getfp('ImGui_OpenPopup')
    OpenPopup.func = CFUNCTYPE(None, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(str_id), c_int(popup_flagsInOptional) if popup_flagsInOptional != None else None)
  OpenPopup.func(args[0], args[1], byref(args[2]) if args[2] != None else None)

def OpenPopupOnItemClick(ctx, str_idInOptional = None, popup_flagsInOptional = None):
  if not hasattr(OpenPopupOnItemClick, 'func'):
    proc = rpr_getfp('ImGui_OpenPopupOnItemClick')
    OpenPopupOnItemClick.func = CFUNCTYPE(None, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(str_idInOptional) if str_idInOptional != None else None, c_int(popup_flagsInOptional) if popup_flagsInOptional != None else None)
  OpenPopupOnItemClick.func(args[0], args[1], byref(args[2]) if args[2] != None else None)

def PopupFlags_None():
  if not hasattr(PopupFlags_None, 'func'):
    proc = rpr_getfp('ImGui_PopupFlags_None')
    PopupFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(PopupFlags_None, 'cache'):
    PopupFlags_None.cache = PopupFlags_None.func()
  return PopupFlags_None.cache

def PopupFlags_MouseButtonLeft():
  if not hasattr(PopupFlags_MouseButtonLeft, 'func'):
    proc = rpr_getfp('ImGui_PopupFlags_MouseButtonLeft')
    PopupFlags_MouseButtonLeft.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(PopupFlags_MouseButtonLeft, 'cache'):
    PopupFlags_MouseButtonLeft.cache = PopupFlags_MouseButtonLeft.func()
  return PopupFlags_MouseButtonLeft.cache

def PopupFlags_MouseButtonMiddle():
  if not hasattr(PopupFlags_MouseButtonMiddle, 'func'):
    proc = rpr_getfp('ImGui_PopupFlags_MouseButtonMiddle')
    PopupFlags_MouseButtonMiddle.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(PopupFlags_MouseButtonMiddle, 'cache'):
    PopupFlags_MouseButtonMiddle.cache = PopupFlags_MouseButtonMiddle.func()
  return PopupFlags_MouseButtonMiddle.cache

def PopupFlags_MouseButtonRight():
  if not hasattr(PopupFlags_MouseButtonRight, 'func'):
    proc = rpr_getfp('ImGui_PopupFlags_MouseButtonRight')
    PopupFlags_MouseButtonRight.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(PopupFlags_MouseButtonRight, 'cache'):
    PopupFlags_MouseButtonRight.cache = PopupFlags_MouseButtonRight.func()
  return PopupFlags_MouseButtonRight.cache

def PopupFlags_NoOpenOverItems():
  if not hasattr(PopupFlags_NoOpenOverItems, 'func'):
    proc = rpr_getfp('ImGui_PopupFlags_NoOpenOverItems')
    PopupFlags_NoOpenOverItems.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(PopupFlags_NoOpenOverItems, 'cache'):
    PopupFlags_NoOpenOverItems.cache = PopupFlags_NoOpenOverItems.func()
  return PopupFlags_NoOpenOverItems.cache

def PopupFlags_AnyPopup():
  if not hasattr(PopupFlags_AnyPopup, 'func'):
    proc = rpr_getfp('ImGui_PopupFlags_AnyPopup')
    PopupFlags_AnyPopup.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(PopupFlags_AnyPopup, 'cache'):
    PopupFlags_AnyPopup.cache = PopupFlags_AnyPopup.func()
  return PopupFlags_AnyPopup.cache

def PopupFlags_AnyPopupId():
  if not hasattr(PopupFlags_AnyPopupId, 'func'):
    proc = rpr_getfp('ImGui_PopupFlags_AnyPopupId')
    PopupFlags_AnyPopupId.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(PopupFlags_AnyPopupId, 'cache'):
    PopupFlags_AnyPopupId.cache = PopupFlags_AnyPopupId.func()
  return PopupFlags_AnyPopupId.cache

def PopupFlags_AnyPopupLevel():
  if not hasattr(PopupFlags_AnyPopupLevel, 'func'):
    proc = rpr_getfp('ImGui_PopupFlags_AnyPopupLevel')
    PopupFlags_AnyPopupLevel.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(PopupFlags_AnyPopupLevel, 'cache'):
    PopupFlags_AnyPopupLevel.cache = PopupFlags_AnyPopupLevel.func()
  return PopupFlags_AnyPopupLevel.cache

def PopupFlags_NoOpenOverExistingPopup():
  if not hasattr(PopupFlags_NoOpenOverExistingPopup, 'func'):
    proc = rpr_getfp('ImGui_PopupFlags_NoOpenOverExistingPopup')
    PopupFlags_NoOpenOverExistingPopup.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(PopupFlags_NoOpenOverExistingPopup, 'cache'):
    PopupFlags_NoOpenOverExistingPopup.cache = PopupFlags_NoOpenOverExistingPopup.func()
  return PopupFlags_NoOpenOverExistingPopup.cache

def PopupFlags_NoReopen():
  if not hasattr(PopupFlags_NoReopen, 'func'):
    proc = rpr_getfp('ImGui_PopupFlags_NoReopen')
    PopupFlags_NoReopen.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(PopupFlags_NoReopen, 'cache'):
    PopupFlags_NoReopen.cache = PopupFlags_NoReopen.func()
  return PopupFlags_NoReopen.cache

def BeginPopupContextItem(ctx, str_idInOptional = None, popup_flagsInOptional = None):
  if not hasattr(BeginPopupContextItem, 'func'):
    proc = rpr_getfp('ImGui_BeginPopupContextItem')
    BeginPopupContextItem.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(str_idInOptional) if str_idInOptional != None else None, c_int(popup_flagsInOptional) if popup_flagsInOptional != None else None)
  rval = BeginPopupContextItem.func(args[0], args[1], byref(args[2]) if args[2] != None else None)
  return rval

def BeginPopupContextWindow(ctx, str_idInOptional = None, popup_flagsInOptional = None):
  if not hasattr(BeginPopupContextWindow, 'func'):
    proc = rpr_getfp('ImGui_BeginPopupContextWindow')
    BeginPopupContextWindow.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(str_idInOptional) if str_idInOptional != None else None, c_int(popup_flagsInOptional) if popup_flagsInOptional != None else None)
  rval = BeginPopupContextWindow.func(args[0], args[1], byref(args[2]) if args[2] != None else None)
  return rval

def BeginItemTooltip(ctx):
  if not hasattr(BeginItemTooltip, 'func'):
    proc = rpr_getfp('ImGui_BeginItemTooltip')
    BeginItemTooltip.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = BeginItemTooltip.func(args[0])
  return rval

def BeginTooltip(ctx):
  if not hasattr(BeginTooltip, 'func'):
    proc = rpr_getfp('ImGui_BeginTooltip')
    BeginTooltip.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = BeginTooltip.func(args[0])
  return rval

def EndTooltip(ctx):
  if not hasattr(EndTooltip, 'func'):
    proc = rpr_getfp('ImGui_EndTooltip')
    EndTooltip.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  EndTooltip.func(args[0])

def SetItemTooltip(ctx, text):
  if not hasattr(SetItemTooltip, 'func'):
    proc = rpr_getfp('ImGui_SetItemTooltip')
    SetItemTooltip.func = CFUNCTYPE(None, c_void_p, c_char_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(text))
  SetItemTooltip.func(args[0], args[1])

def SetTooltip(ctx, text):
  if not hasattr(SetTooltip, 'func'):
    proc = rpr_getfp('ImGui_SetTooltip')
    SetTooltip.func = CFUNCTYPE(None, c_void_p, c_char_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(text))
  SetTooltip.func(args[0], args[1])

def Col_Border():
  if not hasattr(Col_Border, 'func'):
    proc = rpr_getfp('ImGui_Col_Border')
    Col_Border.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_Border, 'cache'):
    Col_Border.cache = Col_Border.func()
  return Col_Border.cache

def Col_BorderShadow():
  if not hasattr(Col_BorderShadow, 'func'):
    proc = rpr_getfp('ImGui_Col_BorderShadow')
    Col_BorderShadow.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_BorderShadow, 'cache'):
    Col_BorderShadow.cache = Col_BorderShadow.func()
  return Col_BorderShadow.cache

def Col_Button():
  if not hasattr(Col_Button, 'func'):
    proc = rpr_getfp('ImGui_Col_Button')
    Col_Button.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_Button, 'cache'):
    Col_Button.cache = Col_Button.func()
  return Col_Button.cache

def Col_ButtonActive():
  if not hasattr(Col_ButtonActive, 'func'):
    proc = rpr_getfp('ImGui_Col_ButtonActive')
    Col_ButtonActive.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_ButtonActive, 'cache'):
    Col_ButtonActive.cache = Col_ButtonActive.func()
  return Col_ButtonActive.cache

def Col_ButtonHovered():
  if not hasattr(Col_ButtonHovered, 'func'):
    proc = rpr_getfp('ImGui_Col_ButtonHovered')
    Col_ButtonHovered.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_ButtonHovered, 'cache'):
    Col_ButtonHovered.cache = Col_ButtonHovered.func()
  return Col_ButtonHovered.cache

def Col_CheckMark():
  if not hasattr(Col_CheckMark, 'func'):
    proc = rpr_getfp('ImGui_Col_CheckMark')
    Col_CheckMark.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_CheckMark, 'cache'):
    Col_CheckMark.cache = Col_CheckMark.func()
  return Col_CheckMark.cache

def Col_ChildBg():
  if not hasattr(Col_ChildBg, 'func'):
    proc = rpr_getfp('ImGui_Col_ChildBg')
    Col_ChildBg.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_ChildBg, 'cache'):
    Col_ChildBg.cache = Col_ChildBg.func()
  return Col_ChildBg.cache

def Col_DockingEmptyBg():
  if not hasattr(Col_DockingEmptyBg, 'func'):
    proc = rpr_getfp('ImGui_Col_DockingEmptyBg')
    Col_DockingEmptyBg.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_DockingEmptyBg, 'cache'):
    Col_DockingEmptyBg.cache = Col_DockingEmptyBg.func()
  return Col_DockingEmptyBg.cache

def Col_DockingPreview():
  if not hasattr(Col_DockingPreview, 'func'):
    proc = rpr_getfp('ImGui_Col_DockingPreview')
    Col_DockingPreview.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_DockingPreview, 'cache'):
    Col_DockingPreview.cache = Col_DockingPreview.func()
  return Col_DockingPreview.cache

def Col_DragDropTarget():
  if not hasattr(Col_DragDropTarget, 'func'):
    proc = rpr_getfp('ImGui_Col_DragDropTarget')
    Col_DragDropTarget.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_DragDropTarget, 'cache'):
    Col_DragDropTarget.cache = Col_DragDropTarget.func()
  return Col_DragDropTarget.cache

def Col_FrameBg():
  if not hasattr(Col_FrameBg, 'func'):
    proc = rpr_getfp('ImGui_Col_FrameBg')
    Col_FrameBg.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_FrameBg, 'cache'):
    Col_FrameBg.cache = Col_FrameBg.func()
  return Col_FrameBg.cache

def Col_FrameBgActive():
  if not hasattr(Col_FrameBgActive, 'func'):
    proc = rpr_getfp('ImGui_Col_FrameBgActive')
    Col_FrameBgActive.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_FrameBgActive, 'cache'):
    Col_FrameBgActive.cache = Col_FrameBgActive.func()
  return Col_FrameBgActive.cache

def Col_FrameBgHovered():
  if not hasattr(Col_FrameBgHovered, 'func'):
    proc = rpr_getfp('ImGui_Col_FrameBgHovered')
    Col_FrameBgHovered.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_FrameBgHovered, 'cache'):
    Col_FrameBgHovered.cache = Col_FrameBgHovered.func()
  return Col_FrameBgHovered.cache

def Col_Header():
  if not hasattr(Col_Header, 'func'):
    proc = rpr_getfp('ImGui_Col_Header')
    Col_Header.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_Header, 'cache'):
    Col_Header.cache = Col_Header.func()
  return Col_Header.cache

def Col_HeaderActive():
  if not hasattr(Col_HeaderActive, 'func'):
    proc = rpr_getfp('ImGui_Col_HeaderActive')
    Col_HeaderActive.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_HeaderActive, 'cache'):
    Col_HeaderActive.cache = Col_HeaderActive.func()
  return Col_HeaderActive.cache

def Col_HeaderHovered():
  if not hasattr(Col_HeaderHovered, 'func'):
    proc = rpr_getfp('ImGui_Col_HeaderHovered')
    Col_HeaderHovered.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_HeaderHovered, 'cache'):
    Col_HeaderHovered.cache = Col_HeaderHovered.func()
  return Col_HeaderHovered.cache

def Col_InputTextCursor():
  if not hasattr(Col_InputTextCursor, 'func'):
    proc = rpr_getfp('ImGui_Col_InputTextCursor')
    Col_InputTextCursor.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_InputTextCursor, 'cache'):
    Col_InputTextCursor.cache = Col_InputTextCursor.func()
  return Col_InputTextCursor.cache

def Col_MenuBarBg():
  if not hasattr(Col_MenuBarBg, 'func'):
    proc = rpr_getfp('ImGui_Col_MenuBarBg')
    Col_MenuBarBg.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_MenuBarBg, 'cache'):
    Col_MenuBarBg.cache = Col_MenuBarBg.func()
  return Col_MenuBarBg.cache

def Col_ModalWindowDimBg():
  if not hasattr(Col_ModalWindowDimBg, 'func'):
    proc = rpr_getfp('ImGui_Col_ModalWindowDimBg')
    Col_ModalWindowDimBg.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_ModalWindowDimBg, 'cache'):
    Col_ModalWindowDimBg.cache = Col_ModalWindowDimBg.func()
  return Col_ModalWindowDimBg.cache

def Col_NavCursor():
  if not hasattr(Col_NavCursor, 'func'):
    proc = rpr_getfp('ImGui_Col_NavCursor')
    Col_NavCursor.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_NavCursor, 'cache'):
    Col_NavCursor.cache = Col_NavCursor.func()
  return Col_NavCursor.cache

def Col_NavWindowingDimBg():
  if not hasattr(Col_NavWindowingDimBg, 'func'):
    proc = rpr_getfp('ImGui_Col_NavWindowingDimBg')
    Col_NavWindowingDimBg.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_NavWindowingDimBg, 'cache'):
    Col_NavWindowingDimBg.cache = Col_NavWindowingDimBg.func()
  return Col_NavWindowingDimBg.cache

def Col_NavWindowingHighlight():
  if not hasattr(Col_NavWindowingHighlight, 'func'):
    proc = rpr_getfp('ImGui_Col_NavWindowingHighlight')
    Col_NavWindowingHighlight.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_NavWindowingHighlight, 'cache'):
    Col_NavWindowingHighlight.cache = Col_NavWindowingHighlight.func()
  return Col_NavWindowingHighlight.cache

def Col_PlotHistogram():
  if not hasattr(Col_PlotHistogram, 'func'):
    proc = rpr_getfp('ImGui_Col_PlotHistogram')
    Col_PlotHistogram.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_PlotHistogram, 'cache'):
    Col_PlotHistogram.cache = Col_PlotHistogram.func()
  return Col_PlotHistogram.cache

def Col_PlotHistogramHovered():
  if not hasattr(Col_PlotHistogramHovered, 'func'):
    proc = rpr_getfp('ImGui_Col_PlotHistogramHovered')
    Col_PlotHistogramHovered.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_PlotHistogramHovered, 'cache'):
    Col_PlotHistogramHovered.cache = Col_PlotHistogramHovered.func()
  return Col_PlotHistogramHovered.cache

def Col_PlotLines():
  if not hasattr(Col_PlotLines, 'func'):
    proc = rpr_getfp('ImGui_Col_PlotLines')
    Col_PlotLines.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_PlotLines, 'cache'):
    Col_PlotLines.cache = Col_PlotLines.func()
  return Col_PlotLines.cache

def Col_PlotLinesHovered():
  if not hasattr(Col_PlotLinesHovered, 'func'):
    proc = rpr_getfp('ImGui_Col_PlotLinesHovered')
    Col_PlotLinesHovered.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_PlotLinesHovered, 'cache'):
    Col_PlotLinesHovered.cache = Col_PlotLinesHovered.func()
  return Col_PlotLinesHovered.cache

def Col_PopupBg():
  if not hasattr(Col_PopupBg, 'func'):
    proc = rpr_getfp('ImGui_Col_PopupBg')
    Col_PopupBg.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_PopupBg, 'cache'):
    Col_PopupBg.cache = Col_PopupBg.func()
  return Col_PopupBg.cache

def Col_ResizeGrip():
  if not hasattr(Col_ResizeGrip, 'func'):
    proc = rpr_getfp('ImGui_Col_ResizeGrip')
    Col_ResizeGrip.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_ResizeGrip, 'cache'):
    Col_ResizeGrip.cache = Col_ResizeGrip.func()
  return Col_ResizeGrip.cache

def Col_ResizeGripActive():
  if not hasattr(Col_ResizeGripActive, 'func'):
    proc = rpr_getfp('ImGui_Col_ResizeGripActive')
    Col_ResizeGripActive.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_ResizeGripActive, 'cache'):
    Col_ResizeGripActive.cache = Col_ResizeGripActive.func()
  return Col_ResizeGripActive.cache

def Col_ResizeGripHovered():
  if not hasattr(Col_ResizeGripHovered, 'func'):
    proc = rpr_getfp('ImGui_Col_ResizeGripHovered')
    Col_ResizeGripHovered.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_ResizeGripHovered, 'cache'):
    Col_ResizeGripHovered.cache = Col_ResizeGripHovered.func()
  return Col_ResizeGripHovered.cache

def Col_ScrollbarBg():
  if not hasattr(Col_ScrollbarBg, 'func'):
    proc = rpr_getfp('ImGui_Col_ScrollbarBg')
    Col_ScrollbarBg.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_ScrollbarBg, 'cache'):
    Col_ScrollbarBg.cache = Col_ScrollbarBg.func()
  return Col_ScrollbarBg.cache

def Col_ScrollbarGrab():
  if not hasattr(Col_ScrollbarGrab, 'func'):
    proc = rpr_getfp('ImGui_Col_ScrollbarGrab')
    Col_ScrollbarGrab.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_ScrollbarGrab, 'cache'):
    Col_ScrollbarGrab.cache = Col_ScrollbarGrab.func()
  return Col_ScrollbarGrab.cache

def Col_ScrollbarGrabActive():
  if not hasattr(Col_ScrollbarGrabActive, 'func'):
    proc = rpr_getfp('ImGui_Col_ScrollbarGrabActive')
    Col_ScrollbarGrabActive.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_ScrollbarGrabActive, 'cache'):
    Col_ScrollbarGrabActive.cache = Col_ScrollbarGrabActive.func()
  return Col_ScrollbarGrabActive.cache

def Col_ScrollbarGrabHovered():
  if not hasattr(Col_ScrollbarGrabHovered, 'func'):
    proc = rpr_getfp('ImGui_Col_ScrollbarGrabHovered')
    Col_ScrollbarGrabHovered.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_ScrollbarGrabHovered, 'cache'):
    Col_ScrollbarGrabHovered.cache = Col_ScrollbarGrabHovered.func()
  return Col_ScrollbarGrabHovered.cache

def Col_Separator():
  if not hasattr(Col_Separator, 'func'):
    proc = rpr_getfp('ImGui_Col_Separator')
    Col_Separator.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_Separator, 'cache'):
    Col_Separator.cache = Col_Separator.func()
  return Col_Separator.cache

def Col_SeparatorActive():
  if not hasattr(Col_SeparatorActive, 'func'):
    proc = rpr_getfp('ImGui_Col_SeparatorActive')
    Col_SeparatorActive.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_SeparatorActive, 'cache'):
    Col_SeparatorActive.cache = Col_SeparatorActive.func()
  return Col_SeparatorActive.cache

def Col_SeparatorHovered():
  if not hasattr(Col_SeparatorHovered, 'func'):
    proc = rpr_getfp('ImGui_Col_SeparatorHovered')
    Col_SeparatorHovered.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_SeparatorHovered, 'cache'):
    Col_SeparatorHovered.cache = Col_SeparatorHovered.func()
  return Col_SeparatorHovered.cache

def Col_SliderGrab():
  if not hasattr(Col_SliderGrab, 'func'):
    proc = rpr_getfp('ImGui_Col_SliderGrab')
    Col_SliderGrab.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_SliderGrab, 'cache'):
    Col_SliderGrab.cache = Col_SliderGrab.func()
  return Col_SliderGrab.cache

def Col_SliderGrabActive():
  if not hasattr(Col_SliderGrabActive, 'func'):
    proc = rpr_getfp('ImGui_Col_SliderGrabActive')
    Col_SliderGrabActive.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_SliderGrabActive, 'cache'):
    Col_SliderGrabActive.cache = Col_SliderGrabActive.func()
  return Col_SliderGrabActive.cache

def Col_Tab():
  if not hasattr(Col_Tab, 'func'):
    proc = rpr_getfp('ImGui_Col_Tab')
    Col_Tab.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_Tab, 'cache'):
    Col_Tab.cache = Col_Tab.func()
  return Col_Tab.cache

def Col_TabDimmed():
  if not hasattr(Col_TabDimmed, 'func'):
    proc = rpr_getfp('ImGui_Col_TabDimmed')
    Col_TabDimmed.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_TabDimmed, 'cache'):
    Col_TabDimmed.cache = Col_TabDimmed.func()
  return Col_TabDimmed.cache

def Col_TabDimmedSelected():
  if not hasattr(Col_TabDimmedSelected, 'func'):
    proc = rpr_getfp('ImGui_Col_TabDimmedSelected')
    Col_TabDimmedSelected.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_TabDimmedSelected, 'cache'):
    Col_TabDimmedSelected.cache = Col_TabDimmedSelected.func()
  return Col_TabDimmedSelected.cache

def Col_TabDimmedSelectedOverline():
  if not hasattr(Col_TabDimmedSelectedOverline, 'func'):
    proc = rpr_getfp('ImGui_Col_TabDimmedSelectedOverline')
    Col_TabDimmedSelectedOverline.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_TabDimmedSelectedOverline, 'cache'):
    Col_TabDimmedSelectedOverline.cache = Col_TabDimmedSelectedOverline.func()
  return Col_TabDimmedSelectedOverline.cache

def Col_TabHovered():
  if not hasattr(Col_TabHovered, 'func'):
    proc = rpr_getfp('ImGui_Col_TabHovered')
    Col_TabHovered.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_TabHovered, 'cache'):
    Col_TabHovered.cache = Col_TabHovered.func()
  return Col_TabHovered.cache

def Col_TabSelected():
  if not hasattr(Col_TabSelected, 'func'):
    proc = rpr_getfp('ImGui_Col_TabSelected')
    Col_TabSelected.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_TabSelected, 'cache'):
    Col_TabSelected.cache = Col_TabSelected.func()
  return Col_TabSelected.cache

def Col_TabSelectedOverline():
  if not hasattr(Col_TabSelectedOverline, 'func'):
    proc = rpr_getfp('ImGui_Col_TabSelectedOverline')
    Col_TabSelectedOverline.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_TabSelectedOverline, 'cache'):
    Col_TabSelectedOverline.cache = Col_TabSelectedOverline.func()
  return Col_TabSelectedOverline.cache

def Col_TableBorderLight():
  if not hasattr(Col_TableBorderLight, 'func'):
    proc = rpr_getfp('ImGui_Col_TableBorderLight')
    Col_TableBorderLight.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_TableBorderLight, 'cache'):
    Col_TableBorderLight.cache = Col_TableBorderLight.func()
  return Col_TableBorderLight.cache

def Col_TableBorderStrong():
  if not hasattr(Col_TableBorderStrong, 'func'):
    proc = rpr_getfp('ImGui_Col_TableBorderStrong')
    Col_TableBorderStrong.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_TableBorderStrong, 'cache'):
    Col_TableBorderStrong.cache = Col_TableBorderStrong.func()
  return Col_TableBorderStrong.cache

def Col_TableHeaderBg():
  if not hasattr(Col_TableHeaderBg, 'func'):
    proc = rpr_getfp('ImGui_Col_TableHeaderBg')
    Col_TableHeaderBg.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_TableHeaderBg, 'cache'):
    Col_TableHeaderBg.cache = Col_TableHeaderBg.func()
  return Col_TableHeaderBg.cache

def Col_TableRowBg():
  if not hasattr(Col_TableRowBg, 'func'):
    proc = rpr_getfp('ImGui_Col_TableRowBg')
    Col_TableRowBg.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_TableRowBg, 'cache'):
    Col_TableRowBg.cache = Col_TableRowBg.func()
  return Col_TableRowBg.cache

def Col_TableRowBgAlt():
  if not hasattr(Col_TableRowBgAlt, 'func'):
    proc = rpr_getfp('ImGui_Col_TableRowBgAlt')
    Col_TableRowBgAlt.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_TableRowBgAlt, 'cache'):
    Col_TableRowBgAlt.cache = Col_TableRowBgAlt.func()
  return Col_TableRowBgAlt.cache

def Col_Text():
  if not hasattr(Col_Text, 'func'):
    proc = rpr_getfp('ImGui_Col_Text')
    Col_Text.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_Text, 'cache'):
    Col_Text.cache = Col_Text.func()
  return Col_Text.cache

def Col_TextDisabled():
  if not hasattr(Col_TextDisabled, 'func'):
    proc = rpr_getfp('ImGui_Col_TextDisabled')
    Col_TextDisabled.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_TextDisabled, 'cache'):
    Col_TextDisabled.cache = Col_TextDisabled.func()
  return Col_TextDisabled.cache

def Col_TextLink():
  if not hasattr(Col_TextLink, 'func'):
    proc = rpr_getfp('ImGui_Col_TextLink')
    Col_TextLink.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_TextLink, 'cache'):
    Col_TextLink.cache = Col_TextLink.func()
  return Col_TextLink.cache

def Col_TextSelectedBg():
  if not hasattr(Col_TextSelectedBg, 'func'):
    proc = rpr_getfp('ImGui_Col_TextSelectedBg')
    Col_TextSelectedBg.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_TextSelectedBg, 'cache'):
    Col_TextSelectedBg.cache = Col_TextSelectedBg.func()
  return Col_TextSelectedBg.cache

def Col_TitleBg():
  if not hasattr(Col_TitleBg, 'func'):
    proc = rpr_getfp('ImGui_Col_TitleBg')
    Col_TitleBg.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_TitleBg, 'cache'):
    Col_TitleBg.cache = Col_TitleBg.func()
  return Col_TitleBg.cache

def Col_TitleBgActive():
  if not hasattr(Col_TitleBgActive, 'func'):
    proc = rpr_getfp('ImGui_Col_TitleBgActive')
    Col_TitleBgActive.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_TitleBgActive, 'cache'):
    Col_TitleBgActive.cache = Col_TitleBgActive.func()
  return Col_TitleBgActive.cache

def Col_TitleBgCollapsed():
  if not hasattr(Col_TitleBgCollapsed, 'func'):
    proc = rpr_getfp('ImGui_Col_TitleBgCollapsed')
    Col_TitleBgCollapsed.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_TitleBgCollapsed, 'cache'):
    Col_TitleBgCollapsed.cache = Col_TitleBgCollapsed.func()
  return Col_TitleBgCollapsed.cache

def Col_TreeLines():
  if not hasattr(Col_TreeLines, 'func'):
    proc = rpr_getfp('ImGui_Col_TreeLines')
    Col_TreeLines.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_TreeLines, 'cache'):
    Col_TreeLines.cache = Col_TreeLines.func()
  return Col_TreeLines.cache

def Col_WindowBg():
  if not hasattr(Col_WindowBg, 'func'):
    proc = rpr_getfp('ImGui_Col_WindowBg')
    Col_WindowBg.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Col_WindowBg, 'cache'):
    Col_WindowBg.cache = Col_WindowBg.func()
  return Col_WindowBg.cache

def DebugFlashStyleColor(ctx, idx):
  if not hasattr(DebugFlashStyleColor, 'func'):
    proc = rpr_getfp('ImGui_DebugFlashStyleColor')
    DebugFlashStyleColor.func = CFUNCTYPE(None, c_void_p, c_int)(proc)
  args = (c_void_p(ctx), c_int(idx))
  DebugFlashStyleColor.func(args[0], args[1])

def GetColor(ctx, idx, alpha_mulInOptional = None):
  if not hasattr(GetColor, 'func'):
    proc = rpr_getfp('ImGui_GetColor')
    GetColor.func = CFUNCTYPE(c_int, c_void_p, c_int, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(idx), c_double(alpha_mulInOptional) if alpha_mulInOptional != None else None)
  rval = GetColor.func(args[0], args[1], byref(args[2]) if args[2] != None else None)
  return rval

def GetColorEx(ctx, col_rgba, alpha_mulInOptional = None):
  if not hasattr(GetColorEx, 'func'):
    proc = rpr_getfp('ImGui_GetColorEx')
    GetColorEx.func = CFUNCTYPE(c_int, c_void_p, c_int, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(col_rgba), c_double(alpha_mulInOptional) if alpha_mulInOptional != None else None)
  rval = GetColorEx.func(args[0], args[1], byref(args[2]) if args[2] != None else None)
  return rval

def GetStyleColor(ctx, idx):
  if not hasattr(GetStyleColor, 'func'):
    proc = rpr_getfp('ImGui_GetStyleColor')
    GetStyleColor.func = CFUNCTYPE(c_int, c_void_p, c_int)(proc)
  args = (c_void_p(ctx), c_int(idx))
  rval = GetStyleColor.func(args[0], args[1])
  return rval

def PopStyleColor(ctx, countInOptional = None):
  if not hasattr(PopStyleColor, 'func'):
    proc = rpr_getfp('ImGui_PopStyleColor')
    PopStyleColor.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(countInOptional) if countInOptional != None else None)
  PopStyleColor.func(args[0], byref(args[1]) if args[1] != None else None)

def PushStyleColor(ctx, idx, col_rgba):
  if not hasattr(PushStyleColor, 'func'):
    proc = rpr_getfp('ImGui_PushStyleColor')
    PushStyleColor.func = CFUNCTYPE(None, c_void_p, c_int, c_int)(proc)
  args = (c_void_p(ctx), c_int(idx), c_int(col_rgba))
  PushStyleColor.func(args[0], args[1], args[2])

def GetStyleVar(ctx, var_idx):
  if not hasattr(GetStyleVar, 'func'):
    proc = rpr_getfp('ImGui_GetStyleVar')
    GetStyleVar.func = CFUNCTYPE(None, c_void_p, c_int, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(var_idx), c_double(0), c_double(0))
  GetStyleVar.func(args[0], args[1], byref(args[2]), byref(args[3]))
  return float(args[2].value), float(args[3].value)

def PopStyleVar(ctx, countInOptional = None):
  if not hasattr(PopStyleVar, 'func'):
    proc = rpr_getfp('ImGui_PopStyleVar')
    PopStyleVar.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(countInOptional) if countInOptional != None else None)
  PopStyleVar.func(args[0], byref(args[1]) if args[1] != None else None)

def PushStyleVar(ctx, idx, val1, val2InOptional = None):
  if not hasattr(PushStyleVar, 'func'):
    proc = rpr_getfp('ImGui_PushStyleVar')
    PushStyleVar.func = CFUNCTYPE(None, c_void_p, c_int, c_double, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(idx), c_double(val1), c_double(val2InOptional) if val2InOptional != None else None)
  PushStyleVar.func(args[0], args[1], args[2], byref(args[3]) if args[3] != None else None)

def PushStyleVarX(ctx, idx, val_x):
  if not hasattr(PushStyleVarX, 'func'):
    proc = rpr_getfp('ImGui_PushStyleVarX')
    PushStyleVarX.func = CFUNCTYPE(None, c_void_p, c_int, c_double)(proc)
  args = (c_void_p(ctx), c_int(idx), c_double(val_x))
  PushStyleVarX.func(args[0], args[1], args[2])

def PushStyleVarY(ctx, idx, val_y):
  if not hasattr(PushStyleVarY, 'func'):
    proc = rpr_getfp('ImGui_PushStyleVarY')
    PushStyleVarY.func = CFUNCTYPE(None, c_void_p, c_int, c_double)(proc)
  args = (c_void_p(ctx), c_int(idx), c_double(val_y))
  PushStyleVarY.func(args[0], args[1], args[2])

def StyleVar_Alpha():
  if not hasattr(StyleVar_Alpha, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_Alpha')
    StyleVar_Alpha.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_Alpha, 'cache'):
    StyleVar_Alpha.cache = StyleVar_Alpha.func()
  return StyleVar_Alpha.cache

def StyleVar_ButtonTextAlign():
  if not hasattr(StyleVar_ButtonTextAlign, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_ButtonTextAlign')
    StyleVar_ButtonTextAlign.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_ButtonTextAlign, 'cache'):
    StyleVar_ButtonTextAlign.cache = StyleVar_ButtonTextAlign.func()
  return StyleVar_ButtonTextAlign.cache

def StyleVar_CellPadding():
  if not hasattr(StyleVar_CellPadding, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_CellPadding')
    StyleVar_CellPadding.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_CellPadding, 'cache'):
    StyleVar_CellPadding.cache = StyleVar_CellPadding.func()
  return StyleVar_CellPadding.cache

def StyleVar_ChildBorderSize():
  if not hasattr(StyleVar_ChildBorderSize, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_ChildBorderSize')
    StyleVar_ChildBorderSize.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_ChildBorderSize, 'cache'):
    StyleVar_ChildBorderSize.cache = StyleVar_ChildBorderSize.func()
  return StyleVar_ChildBorderSize.cache

def StyleVar_ChildRounding():
  if not hasattr(StyleVar_ChildRounding, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_ChildRounding')
    StyleVar_ChildRounding.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_ChildRounding, 'cache'):
    StyleVar_ChildRounding.cache = StyleVar_ChildRounding.func()
  return StyleVar_ChildRounding.cache

def StyleVar_DisabledAlpha():
  if not hasattr(StyleVar_DisabledAlpha, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_DisabledAlpha')
    StyleVar_DisabledAlpha.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_DisabledAlpha, 'cache'):
    StyleVar_DisabledAlpha.cache = StyleVar_DisabledAlpha.func()
  return StyleVar_DisabledAlpha.cache

def StyleVar_FrameBorderSize():
  if not hasattr(StyleVar_FrameBorderSize, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_FrameBorderSize')
    StyleVar_FrameBorderSize.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_FrameBorderSize, 'cache'):
    StyleVar_FrameBorderSize.cache = StyleVar_FrameBorderSize.func()
  return StyleVar_FrameBorderSize.cache

def StyleVar_FramePadding():
  if not hasattr(StyleVar_FramePadding, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_FramePadding')
    StyleVar_FramePadding.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_FramePadding, 'cache'):
    StyleVar_FramePadding.cache = StyleVar_FramePadding.func()
  return StyleVar_FramePadding.cache

def StyleVar_FrameRounding():
  if not hasattr(StyleVar_FrameRounding, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_FrameRounding')
    StyleVar_FrameRounding.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_FrameRounding, 'cache'):
    StyleVar_FrameRounding.cache = StyleVar_FrameRounding.func()
  return StyleVar_FrameRounding.cache

def StyleVar_GrabMinSize():
  if not hasattr(StyleVar_GrabMinSize, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_GrabMinSize')
    StyleVar_GrabMinSize.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_GrabMinSize, 'cache'):
    StyleVar_GrabMinSize.cache = StyleVar_GrabMinSize.func()
  return StyleVar_GrabMinSize.cache

def StyleVar_GrabRounding():
  if not hasattr(StyleVar_GrabRounding, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_GrabRounding')
    StyleVar_GrabRounding.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_GrabRounding, 'cache'):
    StyleVar_GrabRounding.cache = StyleVar_GrabRounding.func()
  return StyleVar_GrabRounding.cache

def StyleVar_ImageBorderSize():
  if not hasattr(StyleVar_ImageBorderSize, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_ImageBorderSize')
    StyleVar_ImageBorderSize.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_ImageBorderSize, 'cache'):
    StyleVar_ImageBorderSize.cache = StyleVar_ImageBorderSize.func()
  return StyleVar_ImageBorderSize.cache

def StyleVar_IndentSpacing():
  if not hasattr(StyleVar_IndentSpacing, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_IndentSpacing')
    StyleVar_IndentSpacing.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_IndentSpacing, 'cache'):
    StyleVar_IndentSpacing.cache = StyleVar_IndentSpacing.func()
  return StyleVar_IndentSpacing.cache

def StyleVar_ItemInnerSpacing():
  if not hasattr(StyleVar_ItemInnerSpacing, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_ItemInnerSpacing')
    StyleVar_ItemInnerSpacing.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_ItemInnerSpacing, 'cache'):
    StyleVar_ItemInnerSpacing.cache = StyleVar_ItemInnerSpacing.func()
  return StyleVar_ItemInnerSpacing.cache

def StyleVar_ItemSpacing():
  if not hasattr(StyleVar_ItemSpacing, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_ItemSpacing')
    StyleVar_ItemSpacing.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_ItemSpacing, 'cache'):
    StyleVar_ItemSpacing.cache = StyleVar_ItemSpacing.func()
  return StyleVar_ItemSpacing.cache

def StyleVar_PopupBorderSize():
  if not hasattr(StyleVar_PopupBorderSize, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_PopupBorderSize')
    StyleVar_PopupBorderSize.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_PopupBorderSize, 'cache'):
    StyleVar_PopupBorderSize.cache = StyleVar_PopupBorderSize.func()
  return StyleVar_PopupBorderSize.cache

def StyleVar_PopupRounding():
  if not hasattr(StyleVar_PopupRounding, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_PopupRounding')
    StyleVar_PopupRounding.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_PopupRounding, 'cache'):
    StyleVar_PopupRounding.cache = StyleVar_PopupRounding.func()
  return StyleVar_PopupRounding.cache

def StyleVar_ScrollbarRounding():
  if not hasattr(StyleVar_ScrollbarRounding, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_ScrollbarRounding')
    StyleVar_ScrollbarRounding.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_ScrollbarRounding, 'cache'):
    StyleVar_ScrollbarRounding.cache = StyleVar_ScrollbarRounding.func()
  return StyleVar_ScrollbarRounding.cache

def StyleVar_ScrollbarSize():
  if not hasattr(StyleVar_ScrollbarSize, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_ScrollbarSize')
    StyleVar_ScrollbarSize.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_ScrollbarSize, 'cache'):
    StyleVar_ScrollbarSize.cache = StyleVar_ScrollbarSize.func()
  return StyleVar_ScrollbarSize.cache

def StyleVar_SelectableTextAlign():
  if not hasattr(StyleVar_SelectableTextAlign, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_SelectableTextAlign')
    StyleVar_SelectableTextAlign.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_SelectableTextAlign, 'cache'):
    StyleVar_SelectableTextAlign.cache = StyleVar_SelectableTextAlign.func()
  return StyleVar_SelectableTextAlign.cache

def StyleVar_SeparatorTextAlign():
  if not hasattr(StyleVar_SeparatorTextAlign, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_SeparatorTextAlign')
    StyleVar_SeparatorTextAlign.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_SeparatorTextAlign, 'cache'):
    StyleVar_SeparatorTextAlign.cache = StyleVar_SeparatorTextAlign.func()
  return StyleVar_SeparatorTextAlign.cache

def StyleVar_SeparatorTextBorderSize():
  if not hasattr(StyleVar_SeparatorTextBorderSize, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_SeparatorTextBorderSize')
    StyleVar_SeparatorTextBorderSize.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_SeparatorTextBorderSize, 'cache'):
    StyleVar_SeparatorTextBorderSize.cache = StyleVar_SeparatorTextBorderSize.func()
  return StyleVar_SeparatorTextBorderSize.cache

def StyleVar_SeparatorTextPadding():
  if not hasattr(StyleVar_SeparatorTextPadding, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_SeparatorTextPadding')
    StyleVar_SeparatorTextPadding.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_SeparatorTextPadding, 'cache'):
    StyleVar_SeparatorTextPadding.cache = StyleVar_SeparatorTextPadding.func()
  return StyleVar_SeparatorTextPadding.cache

def StyleVar_TabBarBorderSize():
  if not hasattr(StyleVar_TabBarBorderSize, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_TabBarBorderSize')
    StyleVar_TabBarBorderSize.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_TabBarBorderSize, 'cache'):
    StyleVar_TabBarBorderSize.cache = StyleVar_TabBarBorderSize.func()
  return StyleVar_TabBarBorderSize.cache

def StyleVar_TabBarOverlineSize():
  if not hasattr(StyleVar_TabBarOverlineSize, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_TabBarOverlineSize')
    StyleVar_TabBarOverlineSize.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_TabBarOverlineSize, 'cache'):
    StyleVar_TabBarOverlineSize.cache = StyleVar_TabBarOverlineSize.func()
  return StyleVar_TabBarOverlineSize.cache

def StyleVar_TabBorderSize():
  if not hasattr(StyleVar_TabBorderSize, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_TabBorderSize')
    StyleVar_TabBorderSize.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_TabBorderSize, 'cache'):
    StyleVar_TabBorderSize.cache = StyleVar_TabBorderSize.func()
  return StyleVar_TabBorderSize.cache

def StyleVar_TabRounding():
  if not hasattr(StyleVar_TabRounding, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_TabRounding')
    StyleVar_TabRounding.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_TabRounding, 'cache'):
    StyleVar_TabRounding.cache = StyleVar_TabRounding.func()
  return StyleVar_TabRounding.cache

def StyleVar_TableAngledHeadersAngle():
  if not hasattr(StyleVar_TableAngledHeadersAngle, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_TableAngledHeadersAngle')
    StyleVar_TableAngledHeadersAngle.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_TableAngledHeadersAngle, 'cache'):
    StyleVar_TableAngledHeadersAngle.cache = StyleVar_TableAngledHeadersAngle.func()
  return StyleVar_TableAngledHeadersAngle.cache

def StyleVar_TableAngledHeadersTextAlign():
  if not hasattr(StyleVar_TableAngledHeadersTextAlign, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_TableAngledHeadersTextAlign')
    StyleVar_TableAngledHeadersTextAlign.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_TableAngledHeadersTextAlign, 'cache'):
    StyleVar_TableAngledHeadersTextAlign.cache = StyleVar_TableAngledHeadersTextAlign.func()
  return StyleVar_TableAngledHeadersTextAlign.cache

def StyleVar_TreeLinesRounding():
  if not hasattr(StyleVar_TreeLinesRounding, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_TreeLinesRounding')
    StyleVar_TreeLinesRounding.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_TreeLinesRounding, 'cache'):
    StyleVar_TreeLinesRounding.cache = StyleVar_TreeLinesRounding.func()
  return StyleVar_TreeLinesRounding.cache

def StyleVar_TreeLinesSize():
  if not hasattr(StyleVar_TreeLinesSize, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_TreeLinesSize')
    StyleVar_TreeLinesSize.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_TreeLinesSize, 'cache'):
    StyleVar_TreeLinesSize.cache = StyleVar_TreeLinesSize.func()
  return StyleVar_TreeLinesSize.cache

def StyleVar_WindowBorderSize():
  if not hasattr(StyleVar_WindowBorderSize, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_WindowBorderSize')
    StyleVar_WindowBorderSize.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_WindowBorderSize, 'cache'):
    StyleVar_WindowBorderSize.cache = StyleVar_WindowBorderSize.func()
  return StyleVar_WindowBorderSize.cache

def StyleVar_WindowMinSize():
  if not hasattr(StyleVar_WindowMinSize, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_WindowMinSize')
    StyleVar_WindowMinSize.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_WindowMinSize, 'cache'):
    StyleVar_WindowMinSize.cache = StyleVar_WindowMinSize.func()
  return StyleVar_WindowMinSize.cache

def StyleVar_WindowPadding():
  if not hasattr(StyleVar_WindowPadding, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_WindowPadding')
    StyleVar_WindowPadding.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_WindowPadding, 'cache'):
    StyleVar_WindowPadding.cache = StyleVar_WindowPadding.func()
  return StyleVar_WindowPadding.cache

def StyleVar_WindowRounding():
  if not hasattr(StyleVar_WindowRounding, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_WindowRounding')
    StyleVar_WindowRounding.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_WindowRounding, 'cache'):
    StyleVar_WindowRounding.cache = StyleVar_WindowRounding.func()
  return StyleVar_WindowRounding.cache

def StyleVar_WindowTitleAlign():
  if not hasattr(StyleVar_WindowTitleAlign, 'func'):
    proc = rpr_getfp('ImGui_StyleVar_WindowTitleAlign')
    StyleVar_WindowTitleAlign.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(StyleVar_WindowTitleAlign, 'cache'):
    StyleVar_WindowTitleAlign.cache = StyleVar_WindowTitleAlign.func()
  return StyleVar_WindowTitleAlign.cache

def BeginTabBar(ctx, str_id, flagsInOptional = None):
  if not hasattr(BeginTabBar, 'func'):
    proc = rpr_getfp('ImGui_BeginTabBar')
    BeginTabBar.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(str_id), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = BeginTabBar.func(args[0], args[1], byref(args[2]) if args[2] != None else None)
  return rval

def EndTabBar(ctx):
  if not hasattr(EndTabBar, 'func'):
    proc = rpr_getfp('ImGui_EndTabBar')
    EndTabBar.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  EndTabBar.func(args[0])

def TabBarFlags_AutoSelectNewTabs():
  if not hasattr(TabBarFlags_AutoSelectNewTabs, 'func'):
    proc = rpr_getfp('ImGui_TabBarFlags_AutoSelectNewTabs')
    TabBarFlags_AutoSelectNewTabs.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TabBarFlags_AutoSelectNewTabs, 'cache'):
    TabBarFlags_AutoSelectNewTabs.cache = TabBarFlags_AutoSelectNewTabs.func()
  return TabBarFlags_AutoSelectNewTabs.cache

def TabBarFlags_DrawSelectedOverline():
  if not hasattr(TabBarFlags_DrawSelectedOverline, 'func'):
    proc = rpr_getfp('ImGui_TabBarFlags_DrawSelectedOverline')
    TabBarFlags_DrawSelectedOverline.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TabBarFlags_DrawSelectedOverline, 'cache'):
    TabBarFlags_DrawSelectedOverline.cache = TabBarFlags_DrawSelectedOverline.func()
  return TabBarFlags_DrawSelectedOverline.cache

def TabBarFlags_FittingPolicyResizeDown():
  if not hasattr(TabBarFlags_FittingPolicyResizeDown, 'func'):
    proc = rpr_getfp('ImGui_TabBarFlags_FittingPolicyResizeDown')
    TabBarFlags_FittingPolicyResizeDown.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TabBarFlags_FittingPolicyResizeDown, 'cache'):
    TabBarFlags_FittingPolicyResizeDown.cache = TabBarFlags_FittingPolicyResizeDown.func()
  return TabBarFlags_FittingPolicyResizeDown.cache

def TabBarFlags_FittingPolicyScroll():
  if not hasattr(TabBarFlags_FittingPolicyScroll, 'func'):
    proc = rpr_getfp('ImGui_TabBarFlags_FittingPolicyScroll')
    TabBarFlags_FittingPolicyScroll.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TabBarFlags_FittingPolicyScroll, 'cache'):
    TabBarFlags_FittingPolicyScroll.cache = TabBarFlags_FittingPolicyScroll.func()
  return TabBarFlags_FittingPolicyScroll.cache

def TabBarFlags_NoCloseWithMiddleMouseButton():
  if not hasattr(TabBarFlags_NoCloseWithMiddleMouseButton, 'func'):
    proc = rpr_getfp('ImGui_TabBarFlags_NoCloseWithMiddleMouseButton')
    TabBarFlags_NoCloseWithMiddleMouseButton.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TabBarFlags_NoCloseWithMiddleMouseButton, 'cache'):
    TabBarFlags_NoCloseWithMiddleMouseButton.cache = TabBarFlags_NoCloseWithMiddleMouseButton.func()
  return TabBarFlags_NoCloseWithMiddleMouseButton.cache

def TabBarFlags_NoTabListScrollingButtons():
  if not hasattr(TabBarFlags_NoTabListScrollingButtons, 'func'):
    proc = rpr_getfp('ImGui_TabBarFlags_NoTabListScrollingButtons')
    TabBarFlags_NoTabListScrollingButtons.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TabBarFlags_NoTabListScrollingButtons, 'cache'):
    TabBarFlags_NoTabListScrollingButtons.cache = TabBarFlags_NoTabListScrollingButtons.func()
  return TabBarFlags_NoTabListScrollingButtons.cache

def TabBarFlags_NoTooltip():
  if not hasattr(TabBarFlags_NoTooltip, 'func'):
    proc = rpr_getfp('ImGui_TabBarFlags_NoTooltip')
    TabBarFlags_NoTooltip.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TabBarFlags_NoTooltip, 'cache'):
    TabBarFlags_NoTooltip.cache = TabBarFlags_NoTooltip.func()
  return TabBarFlags_NoTooltip.cache

def TabBarFlags_None():
  if not hasattr(TabBarFlags_None, 'func'):
    proc = rpr_getfp('ImGui_TabBarFlags_None')
    TabBarFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TabBarFlags_None, 'cache'):
    TabBarFlags_None.cache = TabBarFlags_None.func()
  return TabBarFlags_None.cache

def TabBarFlags_Reorderable():
  if not hasattr(TabBarFlags_Reorderable, 'func'):
    proc = rpr_getfp('ImGui_TabBarFlags_Reorderable')
    TabBarFlags_Reorderable.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TabBarFlags_Reorderable, 'cache'):
    TabBarFlags_Reorderable.cache = TabBarFlags_Reorderable.func()
  return TabBarFlags_Reorderable.cache

def TabBarFlags_TabListPopupButton():
  if not hasattr(TabBarFlags_TabListPopupButton, 'func'):
    proc = rpr_getfp('ImGui_TabBarFlags_TabListPopupButton')
    TabBarFlags_TabListPopupButton.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TabBarFlags_TabListPopupButton, 'cache'):
    TabBarFlags_TabListPopupButton.cache = TabBarFlags_TabListPopupButton.func()
  return TabBarFlags_TabListPopupButton.cache

def BeginTabItem(ctx, label, p_openInOutOptional = None, flagsInOptional = None):
  if not hasattr(BeginTabItem, 'func'):
    proc = rpr_getfp('ImGui_BeginTabItem')
    BeginTabItem.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_bool(p_openInOutOptional) if p_openInOutOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = BeginTabItem.func(args[0], args[1], byref(args[2]) if args[2] != None else None, byref(args[3]) if args[3] != None else None)
  return rval, int(args[2].value) if p_openInOutOptional != None else None

def EndTabItem(ctx):
  if not hasattr(EndTabItem, 'func'):
    proc = rpr_getfp('ImGui_EndTabItem')
    EndTabItem.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  EndTabItem.func(args[0])

def SetTabItemClosed(ctx, tab_or_docked_window_label):
  if not hasattr(SetTabItemClosed, 'func'):
    proc = rpr_getfp('ImGui_SetTabItemClosed')
    SetTabItemClosed.func = CFUNCTYPE(None, c_void_p, c_char_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(tab_or_docked_window_label))
  SetTabItemClosed.func(args[0], args[1])

def TabItemButton(ctx, label, flagsInOptional = None):
  if not hasattr(TabItemButton, 'func'):
    proc = rpr_getfp('ImGui_TabItemButton')
    TabItemButton.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = TabItemButton.func(args[0], args[1], byref(args[2]) if args[2] != None else None)
  return rval

def TabItemFlags_Leading():
  if not hasattr(TabItemFlags_Leading, 'func'):
    proc = rpr_getfp('ImGui_TabItemFlags_Leading')
    TabItemFlags_Leading.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TabItemFlags_Leading, 'cache'):
    TabItemFlags_Leading.cache = TabItemFlags_Leading.func()
  return TabItemFlags_Leading.cache

def TabItemFlags_NoAssumedClosure():
  if not hasattr(TabItemFlags_NoAssumedClosure, 'func'):
    proc = rpr_getfp('ImGui_TabItemFlags_NoAssumedClosure')
    TabItemFlags_NoAssumedClosure.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TabItemFlags_NoAssumedClosure, 'cache'):
    TabItemFlags_NoAssumedClosure.cache = TabItemFlags_NoAssumedClosure.func()
  return TabItemFlags_NoAssumedClosure.cache

def TabItemFlags_NoCloseWithMiddleMouseButton():
  if not hasattr(TabItemFlags_NoCloseWithMiddleMouseButton, 'func'):
    proc = rpr_getfp('ImGui_TabItemFlags_NoCloseWithMiddleMouseButton')
    TabItemFlags_NoCloseWithMiddleMouseButton.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TabItemFlags_NoCloseWithMiddleMouseButton, 'cache'):
    TabItemFlags_NoCloseWithMiddleMouseButton.cache = TabItemFlags_NoCloseWithMiddleMouseButton.func()
  return TabItemFlags_NoCloseWithMiddleMouseButton.cache

def TabItemFlags_NoPushId():
  if not hasattr(TabItemFlags_NoPushId, 'func'):
    proc = rpr_getfp('ImGui_TabItemFlags_NoPushId')
    TabItemFlags_NoPushId.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TabItemFlags_NoPushId, 'cache'):
    TabItemFlags_NoPushId.cache = TabItemFlags_NoPushId.func()
  return TabItemFlags_NoPushId.cache

def TabItemFlags_NoReorder():
  if not hasattr(TabItemFlags_NoReorder, 'func'):
    proc = rpr_getfp('ImGui_TabItemFlags_NoReorder')
    TabItemFlags_NoReorder.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TabItemFlags_NoReorder, 'cache'):
    TabItemFlags_NoReorder.cache = TabItemFlags_NoReorder.func()
  return TabItemFlags_NoReorder.cache

def TabItemFlags_NoTooltip():
  if not hasattr(TabItemFlags_NoTooltip, 'func'):
    proc = rpr_getfp('ImGui_TabItemFlags_NoTooltip')
    TabItemFlags_NoTooltip.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TabItemFlags_NoTooltip, 'cache'):
    TabItemFlags_NoTooltip.cache = TabItemFlags_NoTooltip.func()
  return TabItemFlags_NoTooltip.cache

def TabItemFlags_None():
  if not hasattr(TabItemFlags_None, 'func'):
    proc = rpr_getfp('ImGui_TabItemFlags_None')
    TabItemFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TabItemFlags_None, 'cache'):
    TabItemFlags_None.cache = TabItemFlags_None.func()
  return TabItemFlags_None.cache

def TabItemFlags_SetSelected():
  if not hasattr(TabItemFlags_SetSelected, 'func'):
    proc = rpr_getfp('ImGui_TabItemFlags_SetSelected')
    TabItemFlags_SetSelected.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TabItemFlags_SetSelected, 'cache'):
    TabItemFlags_SetSelected.cache = TabItemFlags_SetSelected.func()
  return TabItemFlags_SetSelected.cache

def TabItemFlags_Trailing():
  if not hasattr(TabItemFlags_Trailing, 'func'):
    proc = rpr_getfp('ImGui_TabItemFlags_Trailing')
    TabItemFlags_Trailing.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TabItemFlags_Trailing, 'cache'):
    TabItemFlags_Trailing.cache = TabItemFlags_Trailing.func()
  return TabItemFlags_Trailing.cache

def TabItemFlags_UnsavedDocument():
  if not hasattr(TabItemFlags_UnsavedDocument, 'func'):
    proc = rpr_getfp('ImGui_TabItemFlags_UnsavedDocument')
    TabItemFlags_UnsavedDocument.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TabItemFlags_UnsavedDocument, 'cache'):
    TabItemFlags_UnsavedDocument.cache = TabItemFlags_UnsavedDocument.func()
  return TabItemFlags_UnsavedDocument.cache

def BeginTable(ctx, str_id, columns, flagsInOptional = None, outer_size_wInOptional = None, outer_size_hInOptional = None, inner_widthInOptional = None):
  if not hasattr(BeginTable, 'func'):
    proc = rpr_getfp('ImGui_BeginTable')
    BeginTable.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_int, c_void_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(str_id), c_int(columns), c_int(flagsInOptional) if flagsInOptional != None else None, c_double(outer_size_wInOptional) if outer_size_wInOptional != None else None, c_double(outer_size_hInOptional) if outer_size_hInOptional != None else None, c_double(inner_widthInOptional) if inner_widthInOptional != None else None)
  rval = BeginTable.func(args[0], args[1], args[2], byref(args[3]) if args[3] != None else None, byref(args[4]) if args[4] != None else None, byref(args[5]) if args[5] != None else None, byref(args[6]) if args[6] != None else None)
  return rval

def EndTable(ctx):
  if not hasattr(EndTable, 'func'):
    proc = rpr_getfp('ImGui_EndTable')
    EndTable.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  EndTable.func(args[0])

def TableGetColumnCount(ctx):
  if not hasattr(TableGetColumnCount, 'func'):
    proc = rpr_getfp('ImGui_TableGetColumnCount')
    TableGetColumnCount.func = CFUNCTYPE(c_int, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = TableGetColumnCount.func(args[0])
  return rval

def TableGetColumnIndex(ctx):
  if not hasattr(TableGetColumnIndex, 'func'):
    proc = rpr_getfp('ImGui_TableGetColumnIndex')
    TableGetColumnIndex.func = CFUNCTYPE(c_int, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = TableGetColumnIndex.func(args[0])
  return rval

def TableGetRowIndex(ctx):
  if not hasattr(TableGetRowIndex, 'func'):
    proc = rpr_getfp('ImGui_TableGetRowIndex')
    TableGetRowIndex.func = CFUNCTYPE(c_int, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = TableGetRowIndex.func(args[0])
  return rval

def TableNextColumn(ctx):
  if not hasattr(TableNextColumn, 'func'):
    proc = rpr_getfp('ImGui_TableNextColumn')
    TableNextColumn.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = TableNextColumn.func(args[0])
  return rval

def TableNextRow(ctx, row_flagsInOptional = None, min_row_heightInOptional = None):
  if not hasattr(TableNextRow, 'func'):
    proc = rpr_getfp('ImGui_TableNextRow')
    TableNextRow.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(row_flagsInOptional) if row_flagsInOptional != None else None, c_double(min_row_heightInOptional) if min_row_heightInOptional != None else None)
  TableNextRow.func(args[0], byref(args[1]) if args[1] != None else None, byref(args[2]) if args[2] != None else None)

def TableRowFlags_Headers():
  if not hasattr(TableRowFlags_Headers, 'func'):
    proc = rpr_getfp('ImGui_TableRowFlags_Headers')
    TableRowFlags_Headers.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableRowFlags_Headers, 'cache'):
    TableRowFlags_Headers.cache = TableRowFlags_Headers.func()
  return TableRowFlags_Headers.cache

def TableRowFlags_None():
  if not hasattr(TableRowFlags_None, 'func'):
    proc = rpr_getfp('ImGui_TableRowFlags_None')
    TableRowFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableRowFlags_None, 'cache'):
    TableRowFlags_None.cache = TableRowFlags_None.func()
  return TableRowFlags_None.cache

def TableSetColumnIndex(ctx, column_n):
  if not hasattr(TableSetColumnIndex, 'func'):
    proc = rpr_getfp('ImGui_TableSetColumnIndex')
    TableSetColumnIndex.func = CFUNCTYPE(c_bool, c_void_p, c_int)(proc)
  args = (c_void_p(ctx), c_int(column_n))
  rval = TableSetColumnIndex.func(args[0], args[1])
  return rval

def TableBgTarget_CellBg():
  if not hasattr(TableBgTarget_CellBg, 'func'):
    proc = rpr_getfp('ImGui_TableBgTarget_CellBg')
    TableBgTarget_CellBg.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableBgTarget_CellBg, 'cache'):
    TableBgTarget_CellBg.cache = TableBgTarget_CellBg.func()
  return TableBgTarget_CellBg.cache

def TableBgTarget_None():
  if not hasattr(TableBgTarget_None, 'func'):
    proc = rpr_getfp('ImGui_TableBgTarget_None')
    TableBgTarget_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableBgTarget_None, 'cache'):
    TableBgTarget_None.cache = TableBgTarget_None.func()
  return TableBgTarget_None.cache

def TableBgTarget_RowBg0():
  if not hasattr(TableBgTarget_RowBg0, 'func'):
    proc = rpr_getfp('ImGui_TableBgTarget_RowBg0')
    TableBgTarget_RowBg0.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableBgTarget_RowBg0, 'cache'):
    TableBgTarget_RowBg0.cache = TableBgTarget_RowBg0.func()
  return TableBgTarget_RowBg0.cache

def TableBgTarget_RowBg1():
  if not hasattr(TableBgTarget_RowBg1, 'func'):
    proc = rpr_getfp('ImGui_TableBgTarget_RowBg1')
    TableBgTarget_RowBg1.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableBgTarget_RowBg1, 'cache'):
    TableBgTarget_RowBg1.cache = TableBgTarget_RowBg1.func()
  return TableBgTarget_RowBg1.cache

def TableSetBgColor(ctx, target, color_rgba, column_nInOptional = None):
  if not hasattr(TableSetBgColor, 'func'):
    proc = rpr_getfp('ImGui_TableSetBgColor')
    TableSetBgColor.func = CFUNCTYPE(None, c_void_p, c_int, c_int, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(target), c_int(color_rgba), c_int(column_nInOptional) if column_nInOptional != None else None)
  TableSetBgColor.func(args[0], args[1], args[2], byref(args[3]) if args[3] != None else None)

def TableAngledHeadersRow(ctx):
  if not hasattr(TableAngledHeadersRow, 'func'):
    proc = rpr_getfp('ImGui_TableAngledHeadersRow')
    TableAngledHeadersRow.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  TableAngledHeadersRow.func(args[0])

def TableGetColumnFlags(ctx, column_nInOptional = None):
  if not hasattr(TableGetColumnFlags, 'func'):
    proc = rpr_getfp('ImGui_TableGetColumnFlags')
    TableGetColumnFlags.func = CFUNCTYPE(c_int, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(column_nInOptional) if column_nInOptional != None else None)
  rval = TableGetColumnFlags.func(args[0], byref(args[1]) if args[1] != None else None)
  return rval

def TableGetColumnName(ctx, column_nInOptional = None):
  if not hasattr(TableGetColumnName, 'func'):
    proc = rpr_getfp('ImGui_TableGetColumnName')
    TableGetColumnName.func = CFUNCTYPE(c_char_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(column_nInOptional) if column_nInOptional != None else None)
  rval = TableGetColumnName.func(args[0], byref(args[1]) if args[1] != None else None)
  return str(rval.decode())

def TableGetHoveredColumn(ctx):
  if not hasattr(TableGetHoveredColumn, 'func'):
    proc = rpr_getfp('ImGui_TableGetHoveredColumn')
    TableGetHoveredColumn.func = CFUNCTYPE(c_int, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = TableGetHoveredColumn.func(args[0])
  return rval

def TableHeader(ctx, label):
  if not hasattr(TableHeader, 'func'):
    proc = rpr_getfp('ImGui_TableHeader')
    TableHeader.func = CFUNCTYPE(None, c_void_p, c_char_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label))
  TableHeader.func(args[0], args[1])

def TableHeadersRow(ctx):
  if not hasattr(TableHeadersRow, 'func'):
    proc = rpr_getfp('ImGui_TableHeadersRow')
    TableHeadersRow.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  TableHeadersRow.func(args[0])

def TableSetColumnEnabled(ctx, column_n, v):
  if not hasattr(TableSetColumnEnabled, 'func'):
    proc = rpr_getfp('ImGui_TableSetColumnEnabled')
    TableSetColumnEnabled.func = CFUNCTYPE(None, c_void_p, c_int, c_bool)(proc)
  args = (c_void_p(ctx), c_int(column_n), c_bool(v))
  TableSetColumnEnabled.func(args[0], args[1], args[2])

def TableSetupColumn(ctx, label, flagsInOptional = None, init_width_or_weightInOptional = None, user_idInOptional = None):
  if not hasattr(TableSetupColumn, 'func'):
    proc = rpr_getfp('ImGui_TableSetupColumn')
    TableSetupColumn.func = CFUNCTYPE(None, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(flagsInOptional) if flagsInOptional != None else None, c_double(init_width_or_weightInOptional) if init_width_or_weightInOptional != None else None, c_int(user_idInOptional) if user_idInOptional != None else None)
  TableSetupColumn.func(args[0], args[1], byref(args[2]) if args[2] != None else None, byref(args[3]) if args[3] != None else None, byref(args[4]) if args[4] != None else None)

def TableSetupScrollFreeze(ctx, cols, rows):
  if not hasattr(TableSetupScrollFreeze, 'func'):
    proc = rpr_getfp('ImGui_TableSetupScrollFreeze')
    TableSetupScrollFreeze.func = CFUNCTYPE(None, c_void_p, c_int, c_int)(proc)
  args = (c_void_p(ctx), c_int(cols), c_int(rows))
  TableSetupScrollFreeze.func(args[0], args[1], args[2])

def TableColumnFlags_None():
  if not hasattr(TableColumnFlags_None, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_None')
    TableColumnFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_None, 'cache'):
    TableColumnFlags_None.cache = TableColumnFlags_None.func()
  return TableColumnFlags_None.cache

def TableColumnFlags_AngledHeader():
  if not hasattr(TableColumnFlags_AngledHeader, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_AngledHeader')
    TableColumnFlags_AngledHeader.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_AngledHeader, 'cache'):
    TableColumnFlags_AngledHeader.cache = TableColumnFlags_AngledHeader.func()
  return TableColumnFlags_AngledHeader.cache

def TableColumnFlags_DefaultHide():
  if not hasattr(TableColumnFlags_DefaultHide, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_DefaultHide')
    TableColumnFlags_DefaultHide.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_DefaultHide, 'cache'):
    TableColumnFlags_DefaultHide.cache = TableColumnFlags_DefaultHide.func()
  return TableColumnFlags_DefaultHide.cache

def TableColumnFlags_DefaultSort():
  if not hasattr(TableColumnFlags_DefaultSort, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_DefaultSort')
    TableColumnFlags_DefaultSort.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_DefaultSort, 'cache'):
    TableColumnFlags_DefaultSort.cache = TableColumnFlags_DefaultSort.func()
  return TableColumnFlags_DefaultSort.cache

def TableColumnFlags_Disabled():
  if not hasattr(TableColumnFlags_Disabled, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_Disabled')
    TableColumnFlags_Disabled.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_Disabled, 'cache'):
    TableColumnFlags_Disabled.cache = TableColumnFlags_Disabled.func()
  return TableColumnFlags_Disabled.cache

def TableColumnFlags_IndentDisable():
  if not hasattr(TableColumnFlags_IndentDisable, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_IndentDisable')
    TableColumnFlags_IndentDisable.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_IndentDisable, 'cache'):
    TableColumnFlags_IndentDisable.cache = TableColumnFlags_IndentDisable.func()
  return TableColumnFlags_IndentDisable.cache

def TableColumnFlags_IndentEnable():
  if not hasattr(TableColumnFlags_IndentEnable, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_IndentEnable')
    TableColumnFlags_IndentEnable.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_IndentEnable, 'cache'):
    TableColumnFlags_IndentEnable.cache = TableColumnFlags_IndentEnable.func()
  return TableColumnFlags_IndentEnable.cache

def TableColumnFlags_NoClip():
  if not hasattr(TableColumnFlags_NoClip, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_NoClip')
    TableColumnFlags_NoClip.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_NoClip, 'cache'):
    TableColumnFlags_NoClip.cache = TableColumnFlags_NoClip.func()
  return TableColumnFlags_NoClip.cache

def TableColumnFlags_NoHeaderLabel():
  if not hasattr(TableColumnFlags_NoHeaderLabel, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_NoHeaderLabel')
    TableColumnFlags_NoHeaderLabel.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_NoHeaderLabel, 'cache'):
    TableColumnFlags_NoHeaderLabel.cache = TableColumnFlags_NoHeaderLabel.func()
  return TableColumnFlags_NoHeaderLabel.cache

def TableColumnFlags_NoHeaderWidth():
  if not hasattr(TableColumnFlags_NoHeaderWidth, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_NoHeaderWidth')
    TableColumnFlags_NoHeaderWidth.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_NoHeaderWidth, 'cache'):
    TableColumnFlags_NoHeaderWidth.cache = TableColumnFlags_NoHeaderWidth.func()
  return TableColumnFlags_NoHeaderWidth.cache

def TableColumnFlags_NoHide():
  if not hasattr(TableColumnFlags_NoHide, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_NoHide')
    TableColumnFlags_NoHide.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_NoHide, 'cache'):
    TableColumnFlags_NoHide.cache = TableColumnFlags_NoHide.func()
  return TableColumnFlags_NoHide.cache

def TableColumnFlags_NoReorder():
  if not hasattr(TableColumnFlags_NoReorder, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_NoReorder')
    TableColumnFlags_NoReorder.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_NoReorder, 'cache'):
    TableColumnFlags_NoReorder.cache = TableColumnFlags_NoReorder.func()
  return TableColumnFlags_NoReorder.cache

def TableColumnFlags_NoResize():
  if not hasattr(TableColumnFlags_NoResize, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_NoResize')
    TableColumnFlags_NoResize.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_NoResize, 'cache'):
    TableColumnFlags_NoResize.cache = TableColumnFlags_NoResize.func()
  return TableColumnFlags_NoResize.cache

def TableColumnFlags_NoSort():
  if not hasattr(TableColumnFlags_NoSort, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_NoSort')
    TableColumnFlags_NoSort.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_NoSort, 'cache'):
    TableColumnFlags_NoSort.cache = TableColumnFlags_NoSort.func()
  return TableColumnFlags_NoSort.cache

def TableColumnFlags_NoSortAscending():
  if not hasattr(TableColumnFlags_NoSortAscending, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_NoSortAscending')
    TableColumnFlags_NoSortAscending.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_NoSortAscending, 'cache'):
    TableColumnFlags_NoSortAscending.cache = TableColumnFlags_NoSortAscending.func()
  return TableColumnFlags_NoSortAscending.cache

def TableColumnFlags_NoSortDescending():
  if not hasattr(TableColumnFlags_NoSortDescending, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_NoSortDescending')
    TableColumnFlags_NoSortDescending.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_NoSortDescending, 'cache'):
    TableColumnFlags_NoSortDescending.cache = TableColumnFlags_NoSortDescending.func()
  return TableColumnFlags_NoSortDescending.cache

def TableColumnFlags_PreferSortAscending():
  if not hasattr(TableColumnFlags_PreferSortAscending, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_PreferSortAscending')
    TableColumnFlags_PreferSortAscending.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_PreferSortAscending, 'cache'):
    TableColumnFlags_PreferSortAscending.cache = TableColumnFlags_PreferSortAscending.func()
  return TableColumnFlags_PreferSortAscending.cache

def TableColumnFlags_PreferSortDescending():
  if not hasattr(TableColumnFlags_PreferSortDescending, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_PreferSortDescending')
    TableColumnFlags_PreferSortDescending.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_PreferSortDescending, 'cache'):
    TableColumnFlags_PreferSortDescending.cache = TableColumnFlags_PreferSortDescending.func()
  return TableColumnFlags_PreferSortDescending.cache

def TableColumnFlags_WidthFixed():
  if not hasattr(TableColumnFlags_WidthFixed, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_WidthFixed')
    TableColumnFlags_WidthFixed.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_WidthFixed, 'cache'):
    TableColumnFlags_WidthFixed.cache = TableColumnFlags_WidthFixed.func()
  return TableColumnFlags_WidthFixed.cache

def TableColumnFlags_WidthStretch():
  if not hasattr(TableColumnFlags_WidthStretch, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_WidthStretch')
    TableColumnFlags_WidthStretch.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_WidthStretch, 'cache'):
    TableColumnFlags_WidthStretch.cache = TableColumnFlags_WidthStretch.func()
  return TableColumnFlags_WidthStretch.cache

def TableColumnFlags_IsEnabled():
  if not hasattr(TableColumnFlags_IsEnabled, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_IsEnabled')
    TableColumnFlags_IsEnabled.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_IsEnabled, 'cache'):
    TableColumnFlags_IsEnabled.cache = TableColumnFlags_IsEnabled.func()
  return TableColumnFlags_IsEnabled.cache

def TableColumnFlags_IsHovered():
  if not hasattr(TableColumnFlags_IsHovered, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_IsHovered')
    TableColumnFlags_IsHovered.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_IsHovered, 'cache'):
    TableColumnFlags_IsHovered.cache = TableColumnFlags_IsHovered.func()
  return TableColumnFlags_IsHovered.cache

def TableColumnFlags_IsSorted():
  if not hasattr(TableColumnFlags_IsSorted, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_IsSorted')
    TableColumnFlags_IsSorted.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_IsSorted, 'cache'):
    TableColumnFlags_IsSorted.cache = TableColumnFlags_IsSorted.func()
  return TableColumnFlags_IsSorted.cache

def TableColumnFlags_IsVisible():
  if not hasattr(TableColumnFlags_IsVisible, 'func'):
    proc = rpr_getfp('ImGui_TableColumnFlags_IsVisible')
    TableColumnFlags_IsVisible.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableColumnFlags_IsVisible, 'cache'):
    TableColumnFlags_IsVisible.cache = TableColumnFlags_IsVisible.func()
  return TableColumnFlags_IsVisible.cache

def SortDirection_Ascending():
  if not hasattr(SortDirection_Ascending, 'func'):
    proc = rpr_getfp('ImGui_SortDirection_Ascending')
    SortDirection_Ascending.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(SortDirection_Ascending, 'cache'):
    SortDirection_Ascending.cache = SortDirection_Ascending.func()
  return SortDirection_Ascending.cache

def SortDirection_Descending():
  if not hasattr(SortDirection_Descending, 'func'):
    proc = rpr_getfp('ImGui_SortDirection_Descending')
    SortDirection_Descending.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(SortDirection_Descending, 'cache'):
    SortDirection_Descending.cache = SortDirection_Descending.func()
  return SortDirection_Descending.cache

def SortDirection_None():
  if not hasattr(SortDirection_None, 'func'):
    proc = rpr_getfp('ImGui_SortDirection_None')
    SortDirection_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(SortDirection_None, 'cache'):
    SortDirection_None.cache = SortDirection_None.func()
  return SortDirection_None.cache

def TableGetColumnSortSpecs(ctx, id):
  if not hasattr(TableGetColumnSortSpecs, 'func'):
    proc = rpr_getfp('ImGui_TableGetColumnSortSpecs')
    TableGetColumnSortSpecs.func = CFUNCTYPE(c_bool, c_void_p, c_int, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(id), c_int(0), c_int(0), c_int(0))
  rval = TableGetColumnSortSpecs.func(args[0], args[1], byref(args[2]), byref(args[3]), byref(args[4]))
  return rval, int(args[2].value), int(args[3].value), int(args[4].value)

def TableNeedSort(ctx):
  if not hasattr(TableNeedSort, 'func'):
    proc = rpr_getfp('ImGui_TableNeedSort')
    TableNeedSort.func = CFUNCTYPE(c_bool, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_bool(0))
  rval = TableNeedSort.func(args[0], byref(args[1]))
  return rval, int(args[1].value)

def TableFlags_None():
  if not hasattr(TableFlags_None, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_None')
    TableFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_None, 'cache'):
    TableFlags_None.cache = TableFlags_None.func()
  return TableFlags_None.cache

def TableFlags_NoClip():
  if not hasattr(TableFlags_NoClip, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_NoClip')
    TableFlags_NoClip.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_NoClip, 'cache'):
    TableFlags_NoClip.cache = TableFlags_NoClip.func()
  return TableFlags_NoClip.cache

def TableFlags_Borders():
  if not hasattr(TableFlags_Borders, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_Borders')
    TableFlags_Borders.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_Borders, 'cache'):
    TableFlags_Borders.cache = TableFlags_Borders.func()
  return TableFlags_Borders.cache

def TableFlags_BordersH():
  if not hasattr(TableFlags_BordersH, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_BordersH')
    TableFlags_BordersH.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_BordersH, 'cache'):
    TableFlags_BordersH.cache = TableFlags_BordersH.func()
  return TableFlags_BordersH.cache

def TableFlags_BordersInner():
  if not hasattr(TableFlags_BordersInner, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_BordersInner')
    TableFlags_BordersInner.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_BordersInner, 'cache'):
    TableFlags_BordersInner.cache = TableFlags_BordersInner.func()
  return TableFlags_BordersInner.cache

def TableFlags_BordersInnerH():
  if not hasattr(TableFlags_BordersInnerH, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_BordersInnerH')
    TableFlags_BordersInnerH.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_BordersInnerH, 'cache'):
    TableFlags_BordersInnerH.cache = TableFlags_BordersInnerH.func()
  return TableFlags_BordersInnerH.cache

def TableFlags_BordersInnerV():
  if not hasattr(TableFlags_BordersInnerV, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_BordersInnerV')
    TableFlags_BordersInnerV.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_BordersInnerV, 'cache'):
    TableFlags_BordersInnerV.cache = TableFlags_BordersInnerV.func()
  return TableFlags_BordersInnerV.cache

def TableFlags_BordersOuter():
  if not hasattr(TableFlags_BordersOuter, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_BordersOuter')
    TableFlags_BordersOuter.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_BordersOuter, 'cache'):
    TableFlags_BordersOuter.cache = TableFlags_BordersOuter.func()
  return TableFlags_BordersOuter.cache

def TableFlags_BordersOuterH():
  if not hasattr(TableFlags_BordersOuterH, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_BordersOuterH')
    TableFlags_BordersOuterH.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_BordersOuterH, 'cache'):
    TableFlags_BordersOuterH.cache = TableFlags_BordersOuterH.func()
  return TableFlags_BordersOuterH.cache

def TableFlags_BordersOuterV():
  if not hasattr(TableFlags_BordersOuterV, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_BordersOuterV')
    TableFlags_BordersOuterV.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_BordersOuterV, 'cache'):
    TableFlags_BordersOuterV.cache = TableFlags_BordersOuterV.func()
  return TableFlags_BordersOuterV.cache

def TableFlags_BordersV():
  if not hasattr(TableFlags_BordersV, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_BordersV')
    TableFlags_BordersV.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_BordersV, 'cache'):
    TableFlags_BordersV.cache = TableFlags_BordersV.func()
  return TableFlags_BordersV.cache

def TableFlags_RowBg():
  if not hasattr(TableFlags_RowBg, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_RowBg')
    TableFlags_RowBg.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_RowBg, 'cache'):
    TableFlags_RowBg.cache = TableFlags_RowBg.func()
  return TableFlags_RowBg.cache

def TableFlags_ContextMenuInBody():
  if not hasattr(TableFlags_ContextMenuInBody, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_ContextMenuInBody')
    TableFlags_ContextMenuInBody.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_ContextMenuInBody, 'cache'):
    TableFlags_ContextMenuInBody.cache = TableFlags_ContextMenuInBody.func()
  return TableFlags_ContextMenuInBody.cache

def TableFlags_Hideable():
  if not hasattr(TableFlags_Hideable, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_Hideable')
    TableFlags_Hideable.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_Hideable, 'cache'):
    TableFlags_Hideable.cache = TableFlags_Hideable.func()
  return TableFlags_Hideable.cache

def TableFlags_NoSavedSettings():
  if not hasattr(TableFlags_NoSavedSettings, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_NoSavedSettings')
    TableFlags_NoSavedSettings.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_NoSavedSettings, 'cache'):
    TableFlags_NoSavedSettings.cache = TableFlags_NoSavedSettings.func()
  return TableFlags_NoSavedSettings.cache

def TableFlags_Reorderable():
  if not hasattr(TableFlags_Reorderable, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_Reorderable')
    TableFlags_Reorderable.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_Reorderable, 'cache'):
    TableFlags_Reorderable.cache = TableFlags_Reorderable.func()
  return TableFlags_Reorderable.cache

def TableFlags_Resizable():
  if not hasattr(TableFlags_Resizable, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_Resizable')
    TableFlags_Resizable.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_Resizable, 'cache'):
    TableFlags_Resizable.cache = TableFlags_Resizable.func()
  return TableFlags_Resizable.cache

def TableFlags_Sortable():
  if not hasattr(TableFlags_Sortable, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_Sortable')
    TableFlags_Sortable.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_Sortable, 'cache'):
    TableFlags_Sortable.cache = TableFlags_Sortable.func()
  return TableFlags_Sortable.cache

def TableFlags_HighlightHoveredColumn():
  if not hasattr(TableFlags_HighlightHoveredColumn, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_HighlightHoveredColumn')
    TableFlags_HighlightHoveredColumn.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_HighlightHoveredColumn, 'cache'):
    TableFlags_HighlightHoveredColumn.cache = TableFlags_HighlightHoveredColumn.func()
  return TableFlags_HighlightHoveredColumn.cache

def TableFlags_NoPadInnerX():
  if not hasattr(TableFlags_NoPadInnerX, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_NoPadInnerX')
    TableFlags_NoPadInnerX.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_NoPadInnerX, 'cache'):
    TableFlags_NoPadInnerX.cache = TableFlags_NoPadInnerX.func()
  return TableFlags_NoPadInnerX.cache

def TableFlags_NoPadOuterX():
  if not hasattr(TableFlags_NoPadOuterX, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_NoPadOuterX')
    TableFlags_NoPadOuterX.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_NoPadOuterX, 'cache'):
    TableFlags_NoPadOuterX.cache = TableFlags_NoPadOuterX.func()
  return TableFlags_NoPadOuterX.cache

def TableFlags_PadOuterX():
  if not hasattr(TableFlags_PadOuterX, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_PadOuterX')
    TableFlags_PadOuterX.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_PadOuterX, 'cache'):
    TableFlags_PadOuterX.cache = TableFlags_PadOuterX.func()
  return TableFlags_PadOuterX.cache

def TableFlags_ScrollX():
  if not hasattr(TableFlags_ScrollX, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_ScrollX')
    TableFlags_ScrollX.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_ScrollX, 'cache'):
    TableFlags_ScrollX.cache = TableFlags_ScrollX.func()
  return TableFlags_ScrollX.cache

def TableFlags_ScrollY():
  if not hasattr(TableFlags_ScrollY, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_ScrollY')
    TableFlags_ScrollY.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_ScrollY, 'cache'):
    TableFlags_ScrollY.cache = TableFlags_ScrollY.func()
  return TableFlags_ScrollY.cache

def TableFlags_NoHostExtendX():
  if not hasattr(TableFlags_NoHostExtendX, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_NoHostExtendX')
    TableFlags_NoHostExtendX.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_NoHostExtendX, 'cache'):
    TableFlags_NoHostExtendX.cache = TableFlags_NoHostExtendX.func()
  return TableFlags_NoHostExtendX.cache

def TableFlags_NoHostExtendY():
  if not hasattr(TableFlags_NoHostExtendY, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_NoHostExtendY')
    TableFlags_NoHostExtendY.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_NoHostExtendY, 'cache'):
    TableFlags_NoHostExtendY.cache = TableFlags_NoHostExtendY.func()
  return TableFlags_NoHostExtendY.cache

def TableFlags_NoKeepColumnsVisible():
  if not hasattr(TableFlags_NoKeepColumnsVisible, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_NoKeepColumnsVisible')
    TableFlags_NoKeepColumnsVisible.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_NoKeepColumnsVisible, 'cache'):
    TableFlags_NoKeepColumnsVisible.cache = TableFlags_NoKeepColumnsVisible.func()
  return TableFlags_NoKeepColumnsVisible.cache

def TableFlags_PreciseWidths():
  if not hasattr(TableFlags_PreciseWidths, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_PreciseWidths')
    TableFlags_PreciseWidths.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_PreciseWidths, 'cache'):
    TableFlags_PreciseWidths.cache = TableFlags_PreciseWidths.func()
  return TableFlags_PreciseWidths.cache

def TableFlags_SizingFixedFit():
  if not hasattr(TableFlags_SizingFixedFit, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_SizingFixedFit')
    TableFlags_SizingFixedFit.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_SizingFixedFit, 'cache'):
    TableFlags_SizingFixedFit.cache = TableFlags_SizingFixedFit.func()
  return TableFlags_SizingFixedFit.cache

def TableFlags_SizingFixedSame():
  if not hasattr(TableFlags_SizingFixedSame, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_SizingFixedSame')
    TableFlags_SizingFixedSame.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_SizingFixedSame, 'cache'):
    TableFlags_SizingFixedSame.cache = TableFlags_SizingFixedSame.func()
  return TableFlags_SizingFixedSame.cache

def TableFlags_SizingStretchProp():
  if not hasattr(TableFlags_SizingStretchProp, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_SizingStretchProp')
    TableFlags_SizingStretchProp.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_SizingStretchProp, 'cache'):
    TableFlags_SizingStretchProp.cache = TableFlags_SizingStretchProp.func()
  return TableFlags_SizingStretchProp.cache

def TableFlags_SizingStretchSame():
  if not hasattr(TableFlags_SizingStretchSame, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_SizingStretchSame')
    TableFlags_SizingStretchSame.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_SizingStretchSame, 'cache'):
    TableFlags_SizingStretchSame.cache = TableFlags_SizingStretchSame.func()
  return TableFlags_SizingStretchSame.cache

def TableFlags_SortMulti():
  if not hasattr(TableFlags_SortMulti, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_SortMulti')
    TableFlags_SortMulti.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_SortMulti, 'cache'):
    TableFlags_SortMulti.cache = TableFlags_SortMulti.func()
  return TableFlags_SortMulti.cache

def TableFlags_SortTristate():
  if not hasattr(TableFlags_SortTristate, 'func'):
    proc = rpr_getfp('ImGui_TableFlags_SortTristate')
    TableFlags_SortTristate.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TableFlags_SortTristate, 'cache'):
    TableFlags_SortTristate.cache = TableFlags_SortTristate.func()
  return TableFlags_SortTristate.cache

def AlignTextToFramePadding(ctx):
  if not hasattr(AlignTextToFramePadding, 'func'):
    proc = rpr_getfp('ImGui_AlignTextToFramePadding')
    AlignTextToFramePadding.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  AlignTextToFramePadding.func(args[0])

def Bullet(ctx):
  if not hasattr(Bullet, 'func'):
    proc = rpr_getfp('ImGui_Bullet')
    Bullet.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  Bullet.func(args[0])

def BulletText(ctx, text):
  if not hasattr(BulletText, 'func'):
    proc = rpr_getfp('ImGui_BulletText')
    BulletText.func = CFUNCTYPE(None, c_void_p, c_char_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(text))
  BulletText.func(args[0], args[1])

def CalcTextSize(ctx, text, hide_text_after_double_hashInOptional = None, wrap_widthInOptional = None):
  if not hasattr(CalcTextSize, 'func'):
    proc = rpr_getfp('ImGui_CalcTextSize')
    CalcTextSize.func = CFUNCTYPE(None, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(text), c_double(0), c_double(0), c_bool(hide_text_after_double_hashInOptional) if hide_text_after_double_hashInOptional != None else None, c_double(wrap_widthInOptional) if wrap_widthInOptional != None else None)
  CalcTextSize.func(args[0], args[1], byref(args[2]), byref(args[3]), byref(args[4]) if args[4] != None else None, byref(args[5]) if args[5] != None else None)
  return float(args[2].value), float(args[3].value)

def DebugTextEncoding(ctx, text):
  if not hasattr(DebugTextEncoding, 'func'):
    proc = rpr_getfp('ImGui_DebugTextEncoding')
    DebugTextEncoding.func = CFUNCTYPE(None, c_void_p, c_char_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(text))
  DebugTextEncoding.func(args[0], args[1])

def GetFrameHeight(ctx):
  if not hasattr(GetFrameHeight, 'func'):
    proc = rpr_getfp('ImGui_GetFrameHeight')
    GetFrameHeight.func = CFUNCTYPE(c_double, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetFrameHeight.func(args[0])
  return rval

def GetFrameHeightWithSpacing(ctx):
  if not hasattr(GetFrameHeightWithSpacing, 'func'):
    proc = rpr_getfp('ImGui_GetFrameHeightWithSpacing')
    GetFrameHeightWithSpacing.func = CFUNCTYPE(c_double, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetFrameHeightWithSpacing.func(args[0])
  return rval

def GetTextLineHeight(ctx):
  if not hasattr(GetTextLineHeight, 'func'):
    proc = rpr_getfp('ImGui_GetTextLineHeight')
    GetTextLineHeight.func = CFUNCTYPE(c_double, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetTextLineHeight.func(args[0])
  return rval

def GetTextLineHeightWithSpacing(ctx):
  if not hasattr(GetTextLineHeightWithSpacing, 'func'):
    proc = rpr_getfp('ImGui_GetTextLineHeightWithSpacing')
    GetTextLineHeightWithSpacing.func = CFUNCTYPE(c_double, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetTextLineHeightWithSpacing.func(args[0])
  return rval

def LabelText(ctx, label, text):
  if not hasattr(LabelText, 'func'):
    proc = rpr_getfp('ImGui_LabelText')
    LabelText.func = CFUNCTYPE(None, c_void_p, c_char_p, c_char_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), rpr_packsc(text))
  LabelText.func(args[0], args[1], args[2])

def PopTextWrapPos(ctx):
  if not hasattr(PopTextWrapPos, 'func'):
    proc = rpr_getfp('ImGui_PopTextWrapPos')
    PopTextWrapPos.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  PopTextWrapPos.func(args[0])

def PushTextWrapPos(ctx, wrap_local_pos_xInOptional = None):
  if not hasattr(PushTextWrapPos, 'func'):
    proc = rpr_getfp('ImGui_PushTextWrapPos')
    PushTextWrapPos.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(wrap_local_pos_xInOptional) if wrap_local_pos_xInOptional != None else None)
  PushTextWrapPos.func(args[0], byref(args[1]) if args[1] != None else None)

def Text(ctx, text):
  if not hasattr(Text, 'func'):
    proc = rpr_getfp('ImGui_Text')
    Text.func = CFUNCTYPE(None, c_void_p, c_char_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(text))
  Text.func(args[0], args[1])

def TextColored(ctx, col_rgba, text):
  if not hasattr(TextColored, 'func'):
    proc = rpr_getfp('ImGui_TextColored')
    TextColored.func = CFUNCTYPE(None, c_void_p, c_int, c_char_p)(proc)
  args = (c_void_p(ctx), c_int(col_rgba), rpr_packsc(text))
  TextColored.func(args[0], args[1], args[2])

def TextDisabled(ctx, text):
  if not hasattr(TextDisabled, 'func'):
    proc = rpr_getfp('ImGui_TextDisabled')
    TextDisabled.func = CFUNCTYPE(None, c_void_p, c_char_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(text))
  TextDisabled.func(args[0], args[1])

def TextLink(ctx, label):
  if not hasattr(TextLink, 'func'):
    proc = rpr_getfp('ImGui_TextLink')
    TextLink.func = CFUNCTYPE(c_bool, c_void_p, c_char_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label))
  rval = TextLink.func(args[0], args[1])
  return rval

def TextLinkOpenURL(ctx, label, urlInOptional = None):
  if not hasattr(TextLinkOpenURL, 'func'):
    proc = rpr_getfp('ImGui_TextLinkOpenURL')
    TextLinkOpenURL.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_char_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), rpr_packsc(urlInOptional) if urlInOptional != None else None)
  rval = TextLinkOpenURL.func(args[0], args[1], args[2])
  return rval

def TextWrapped(ctx, text):
  if not hasattr(TextWrapped, 'func'):
    proc = rpr_getfp('ImGui_TextWrapped')
    TextWrapped.func = CFUNCTYPE(None, c_void_p, c_char_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(text))
  TextWrapped.func(args[0], args[1])

def InputDouble(ctx, label, vInOut, stepInOptional = None, step_fastInOptional = None, formatInOptional = None, flagsInOptional = None):
  if not hasattr(InputDouble, 'func'):
    proc = rpr_getfp('ImGui_InputDouble')
    InputDouble.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_double(vInOut), c_double(stepInOptional) if stepInOptional != None else None, c_double(step_fastInOptional) if step_fastInOptional != None else None, rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = InputDouble.func(args[0], args[1], byref(args[2]), byref(args[3]) if args[3] != None else None, byref(args[4]) if args[4] != None else None, args[5], byref(args[6]) if args[6] != None else None)
  return rval, float(args[2].value)

def InputDouble2(ctx, label, v1InOut, v2InOut, formatInOptional = None, flagsInOptional = None):
  if not hasattr(InputDouble2, 'func'):
    proc = rpr_getfp('ImGui_InputDouble2')
    InputDouble2.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_double(v1InOut), c_double(v2InOut), rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = InputDouble2.func(args[0], args[1], byref(args[2]), byref(args[3]), args[4], byref(args[5]) if args[5] != None else None)
  return rval, float(args[2].value), float(args[3].value)

def InputDouble3(ctx, label, v1InOut, v2InOut, v3InOut, formatInOptional = None, flagsInOptional = None):
  if not hasattr(InputDouble3, 'func'):
    proc = rpr_getfp('ImGui_InputDouble3')
    InputDouble3.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_double(v1InOut), c_double(v2InOut), c_double(v3InOut), rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = InputDouble3.func(args[0], args[1], byref(args[2]), byref(args[3]), byref(args[4]), args[5], byref(args[6]) if args[6] != None else None)
  return rval, float(args[2].value), float(args[3].value), float(args[4].value)

def InputDouble4(ctx, label, v1InOut, v2InOut, v3InOut, v4InOut, formatInOptional = None, flagsInOptional = None):
  if not hasattr(InputDouble4, 'func'):
    proc = rpr_getfp('ImGui_InputDouble4')
    InputDouble4.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_double(v1InOut), c_double(v2InOut), c_double(v3InOut), c_double(v4InOut), rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = InputDouble4.func(args[0], args[1], byref(args[2]), byref(args[3]), byref(args[4]), byref(args[5]), args[6], byref(args[7]) if args[7] != None else None)
  return rval, float(args[2].value), float(args[3].value), float(args[4].value), float(args[5].value)

def InputDoubleN(ctx, label, values, stepInOptional = None, step_fastInOptional = None, formatInOptional = None, flagsInOptional = None):
  if not hasattr(InputDoubleN, 'func'):
    proc = rpr_getfp('ImGui_InputDoubleN')
    InputDoubleN.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_void_p(values), c_double(stepInOptional) if stepInOptional != None else None, c_double(step_fastInOptional) if step_fastInOptional != None else None, rpr_packsc(formatInOptional) if formatInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = InputDoubleN.func(args[0], args[1], args[2], byref(args[3]) if args[3] != None else None, byref(args[4]) if args[4] != None else None, args[5], byref(args[6]) if args[6] != None else None)
  return rval

def InputInt(ctx, label, vInOut, stepInOptional = None, step_fastInOptional = None, flagsInOptional = None):
  if not hasattr(InputInt, 'func'):
    proc = rpr_getfp('ImGui_InputInt')
    InputInt.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(vInOut), c_int(stepInOptional) if stepInOptional != None else None, c_int(step_fastInOptional) if step_fastInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = InputInt.func(args[0], args[1], byref(args[2]), byref(args[3]) if args[3] != None else None, byref(args[4]) if args[4] != None else None, byref(args[5]) if args[5] != None else None)
  return rval, int(args[2].value)

def InputInt2(ctx, label, v1InOut, v2InOut, flagsInOptional = None):
  if not hasattr(InputInt2, 'func'):
    proc = rpr_getfp('ImGui_InputInt2')
    InputInt2.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(v1InOut), c_int(v2InOut), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = InputInt2.func(args[0], args[1], byref(args[2]), byref(args[3]), byref(args[4]) if args[4] != None else None)
  return rval, int(args[2].value), int(args[3].value)

def InputInt3(ctx, label, v1InOut, v2InOut, v3InOut, flagsInOptional = None):
  if not hasattr(InputInt3, 'func'):
    proc = rpr_getfp('ImGui_InputInt3')
    InputInt3.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(v1InOut), c_int(v2InOut), c_int(v3InOut), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = InputInt3.func(args[0], args[1], byref(args[2]), byref(args[3]), byref(args[4]), byref(args[5]) if args[5] != None else None)
  return rval, int(args[2].value), int(args[3].value), int(args[4].value)

def InputInt4(ctx, label, v1InOut, v2InOut, v3InOut, v4InOut, flagsInOptional = None):
  if not hasattr(InputInt4, 'func'):
    proc = rpr_getfp('ImGui_InputInt4')
    InputInt4.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(v1InOut), c_int(v2InOut), c_int(v3InOut), c_int(v4InOut), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = InputInt4.func(args[0], args[1], byref(args[2]), byref(args[3]), byref(args[4]), byref(args[5]), byref(args[6]) if args[6] != None else None)
  return rval, int(args[2].value), int(args[3].value), int(args[4].value), int(args[5].value)

def InputText(ctx, label, bufInOutNeedBig, flagsInOptional = None, callbackInOptional = None):
  if not hasattr(InputText, 'func'):
    proc = rpr_getfp('ImGui_InputText')
    InputText.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_char_p, c_int, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), rpr_packs(bufInOutNeedBig), c_int(4096), c_int(flagsInOptional) if flagsInOptional != None else None, c_void_p(callbackInOptional) if callbackInOptional != None else None)
  rval = InputText.func(args[0], args[1], args[2], args[3], byref(args[4]) if args[4] != None else None, args[5])
  return rval, rpr_unpacks(args[2])

def InputTextMultiline(ctx, label, bufInOutNeedBig, size_wInOptional = None, size_hInOptional = None, flagsInOptional = None, callbackInOptional = None):
  if not hasattr(InputTextMultiline, 'func'):
    proc = rpr_getfp('ImGui_InputTextMultiline')
    InputTextMultiline.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_char_p, c_int, c_void_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), rpr_packs(bufInOutNeedBig), c_int(4096), c_double(size_wInOptional) if size_wInOptional != None else None, c_double(size_hInOptional) if size_hInOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None, c_void_p(callbackInOptional) if callbackInOptional != None else None)
  rval = InputTextMultiline.func(args[0], args[1], args[2], args[3], byref(args[4]) if args[4] != None else None, byref(args[5]) if args[5] != None else None, byref(args[6]) if args[6] != None else None, args[7])
  return rval, rpr_unpacks(args[2])

def InputTextWithHint(ctx, label, hint, bufInOutNeedBig, flagsInOptional = None, callbackInOptional = None):
  if not hasattr(InputTextWithHint, 'func'):
    proc = rpr_getfp('ImGui_InputTextWithHint')
    InputTextWithHint.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_char_p, c_char_p, c_int, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), rpr_packsc(hint), rpr_packs(bufInOutNeedBig), c_int(4096), c_int(flagsInOptional) if flagsInOptional != None else None, c_void_p(callbackInOptional) if callbackInOptional != None else None)
  rval = InputTextWithHint.func(args[0], args[1], args[2], args[3], args[4], byref(args[5]) if args[5] != None else None, args[6])
  return rval, rpr_unpacks(args[3])

def InputTextFlags_None():
  if not hasattr(InputTextFlags_None, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_None')
    InputTextFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_None, 'cache'):
    InputTextFlags_None.cache = InputTextFlags_None.func()
  return InputTextFlags_None.cache

def InputTextFlags_CharsDecimal():
  if not hasattr(InputTextFlags_CharsDecimal, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_CharsDecimal')
    InputTextFlags_CharsDecimal.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_CharsDecimal, 'cache'):
    InputTextFlags_CharsDecimal.cache = InputTextFlags_CharsDecimal.func()
  return InputTextFlags_CharsDecimal.cache

def InputTextFlags_CharsHexadecimal():
  if not hasattr(InputTextFlags_CharsHexadecimal, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_CharsHexadecimal')
    InputTextFlags_CharsHexadecimal.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_CharsHexadecimal, 'cache'):
    InputTextFlags_CharsHexadecimal.cache = InputTextFlags_CharsHexadecimal.func()
  return InputTextFlags_CharsHexadecimal.cache

def InputTextFlags_CharsNoBlank():
  if not hasattr(InputTextFlags_CharsNoBlank, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_CharsNoBlank')
    InputTextFlags_CharsNoBlank.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_CharsNoBlank, 'cache'):
    InputTextFlags_CharsNoBlank.cache = InputTextFlags_CharsNoBlank.func()
  return InputTextFlags_CharsNoBlank.cache

def InputTextFlags_CharsScientific():
  if not hasattr(InputTextFlags_CharsScientific, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_CharsScientific')
    InputTextFlags_CharsScientific.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_CharsScientific, 'cache'):
    InputTextFlags_CharsScientific.cache = InputTextFlags_CharsScientific.func()
  return InputTextFlags_CharsScientific.cache

def InputTextFlags_CharsUppercase():
  if not hasattr(InputTextFlags_CharsUppercase, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_CharsUppercase')
    InputTextFlags_CharsUppercase.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_CharsUppercase, 'cache'):
    InputTextFlags_CharsUppercase.cache = InputTextFlags_CharsUppercase.func()
  return InputTextFlags_CharsUppercase.cache

def InputTextFlags_CallbackAlways():
  if not hasattr(InputTextFlags_CallbackAlways, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_CallbackAlways')
    InputTextFlags_CallbackAlways.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_CallbackAlways, 'cache'):
    InputTextFlags_CallbackAlways.cache = InputTextFlags_CallbackAlways.func()
  return InputTextFlags_CallbackAlways.cache

def InputTextFlags_CallbackCharFilter():
  if not hasattr(InputTextFlags_CallbackCharFilter, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_CallbackCharFilter')
    InputTextFlags_CallbackCharFilter.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_CallbackCharFilter, 'cache'):
    InputTextFlags_CallbackCharFilter.cache = InputTextFlags_CallbackCharFilter.func()
  return InputTextFlags_CallbackCharFilter.cache

def InputTextFlags_CallbackCompletion():
  if not hasattr(InputTextFlags_CallbackCompletion, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_CallbackCompletion')
    InputTextFlags_CallbackCompletion.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_CallbackCompletion, 'cache'):
    InputTextFlags_CallbackCompletion.cache = InputTextFlags_CallbackCompletion.func()
  return InputTextFlags_CallbackCompletion.cache

def InputTextFlags_CallbackEdit():
  if not hasattr(InputTextFlags_CallbackEdit, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_CallbackEdit')
    InputTextFlags_CallbackEdit.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_CallbackEdit, 'cache'):
    InputTextFlags_CallbackEdit.cache = InputTextFlags_CallbackEdit.func()
  return InputTextFlags_CallbackEdit.cache

def InputTextFlags_CallbackHistory():
  if not hasattr(InputTextFlags_CallbackHistory, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_CallbackHistory')
    InputTextFlags_CallbackHistory.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_CallbackHistory, 'cache'):
    InputTextFlags_CallbackHistory.cache = InputTextFlags_CallbackHistory.func()
  return InputTextFlags_CallbackHistory.cache

def InputTextFlags_AllowTabInput():
  if not hasattr(InputTextFlags_AllowTabInput, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_AllowTabInput')
    InputTextFlags_AllowTabInput.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_AllowTabInput, 'cache'):
    InputTextFlags_AllowTabInput.cache = InputTextFlags_AllowTabInput.func()
  return InputTextFlags_AllowTabInput.cache

def InputTextFlags_CtrlEnterForNewLine():
  if not hasattr(InputTextFlags_CtrlEnterForNewLine, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_CtrlEnterForNewLine')
    InputTextFlags_CtrlEnterForNewLine.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_CtrlEnterForNewLine, 'cache'):
    InputTextFlags_CtrlEnterForNewLine.cache = InputTextFlags_CtrlEnterForNewLine.func()
  return InputTextFlags_CtrlEnterForNewLine.cache

def InputTextFlags_EnterReturnsTrue():
  if not hasattr(InputTextFlags_EnterReturnsTrue, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_EnterReturnsTrue')
    InputTextFlags_EnterReturnsTrue.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_EnterReturnsTrue, 'cache'):
    InputTextFlags_EnterReturnsTrue.cache = InputTextFlags_EnterReturnsTrue.func()
  return InputTextFlags_EnterReturnsTrue.cache

def InputTextFlags_EscapeClearsAll():
  if not hasattr(InputTextFlags_EscapeClearsAll, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_EscapeClearsAll')
    InputTextFlags_EscapeClearsAll.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_EscapeClearsAll, 'cache'):
    InputTextFlags_EscapeClearsAll.cache = InputTextFlags_EscapeClearsAll.func()
  return InputTextFlags_EscapeClearsAll.cache

def InputTextFlags_AlwaysOverwrite():
  if not hasattr(InputTextFlags_AlwaysOverwrite, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_AlwaysOverwrite')
    InputTextFlags_AlwaysOverwrite.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_AlwaysOverwrite, 'cache'):
    InputTextFlags_AlwaysOverwrite.cache = InputTextFlags_AlwaysOverwrite.func()
  return InputTextFlags_AlwaysOverwrite.cache

def InputTextFlags_AutoSelectAll():
  if not hasattr(InputTextFlags_AutoSelectAll, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_AutoSelectAll')
    InputTextFlags_AutoSelectAll.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_AutoSelectAll, 'cache'):
    InputTextFlags_AutoSelectAll.cache = InputTextFlags_AutoSelectAll.func()
  return InputTextFlags_AutoSelectAll.cache

def InputTextFlags_DisplayEmptyRefVal():
  if not hasattr(InputTextFlags_DisplayEmptyRefVal, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_DisplayEmptyRefVal')
    InputTextFlags_DisplayEmptyRefVal.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_DisplayEmptyRefVal, 'cache'):
    InputTextFlags_DisplayEmptyRefVal.cache = InputTextFlags_DisplayEmptyRefVal.func()
  return InputTextFlags_DisplayEmptyRefVal.cache

def InputTextFlags_ElideLeft():
  if not hasattr(InputTextFlags_ElideLeft, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_ElideLeft')
    InputTextFlags_ElideLeft.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_ElideLeft, 'cache'):
    InputTextFlags_ElideLeft.cache = InputTextFlags_ElideLeft.func()
  return InputTextFlags_ElideLeft.cache

def InputTextFlags_NoHorizontalScroll():
  if not hasattr(InputTextFlags_NoHorizontalScroll, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_NoHorizontalScroll')
    InputTextFlags_NoHorizontalScroll.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_NoHorizontalScroll, 'cache'):
    InputTextFlags_NoHorizontalScroll.cache = InputTextFlags_NoHorizontalScroll.func()
  return InputTextFlags_NoHorizontalScroll.cache

def InputTextFlags_NoUndoRedo():
  if not hasattr(InputTextFlags_NoUndoRedo, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_NoUndoRedo')
    InputTextFlags_NoUndoRedo.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_NoUndoRedo, 'cache'):
    InputTextFlags_NoUndoRedo.cache = InputTextFlags_NoUndoRedo.func()
  return InputTextFlags_NoUndoRedo.cache

def InputTextFlags_ParseEmptyRefVal():
  if not hasattr(InputTextFlags_ParseEmptyRefVal, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_ParseEmptyRefVal')
    InputTextFlags_ParseEmptyRefVal.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_ParseEmptyRefVal, 'cache'):
    InputTextFlags_ParseEmptyRefVal.cache = InputTextFlags_ParseEmptyRefVal.func()
  return InputTextFlags_ParseEmptyRefVal.cache

def InputTextFlags_Password():
  if not hasattr(InputTextFlags_Password, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_Password')
    InputTextFlags_Password.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_Password, 'cache'):
    InputTextFlags_Password.cache = InputTextFlags_Password.func()
  return InputTextFlags_Password.cache

def InputTextFlags_ReadOnly():
  if not hasattr(InputTextFlags_ReadOnly, 'func'):
    proc = rpr_getfp('ImGui_InputTextFlags_ReadOnly')
    InputTextFlags_ReadOnly.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(InputTextFlags_ReadOnly, 'cache'):
    InputTextFlags_ReadOnly.cache = InputTextFlags_ReadOnly.func()
  return InputTextFlags_ReadOnly.cache

def CreateTextFilter(default_filterInOptional = None):
  if not hasattr(CreateTextFilter, 'func'):
    proc = rpr_getfp('ImGui_CreateTextFilter')
    CreateTextFilter.func = CFUNCTYPE(c_void_p, c_char_p)(proc)
  args = (rpr_packsc(default_filterInOptional) if default_filterInOptional != None else None,)
  rval = CreateTextFilter.func(args[0])
  return rval

def TextFilter_Clear(filter):
  if not hasattr(TextFilter_Clear, 'func'):
    proc = rpr_getfp('ImGui_TextFilter_Clear')
    TextFilter_Clear.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(filter),)
  TextFilter_Clear.func(args[0])

def TextFilter_Draw(filter, ctx, labelInOptional = None, widthInOptional = None):
  if not hasattr(TextFilter_Draw, 'func'):
    proc = rpr_getfp('ImGui_TextFilter_Draw')
    TextFilter_Draw.func = CFUNCTYPE(c_bool, c_void_p, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(filter), c_void_p(ctx), rpr_packsc(labelInOptional) if labelInOptional != None else None, c_double(widthInOptional) if widthInOptional != None else None)
  rval = TextFilter_Draw.func(args[0], args[1], args[2], byref(args[3]) if args[3] != None else None)
  return rval

def TextFilter_Get(filter):
  if not hasattr(TextFilter_Get, 'func'):
    proc = rpr_getfp('ImGui_TextFilter_Get')
    TextFilter_Get.func = CFUNCTYPE(c_char_p, c_void_p)(proc)
  args = (c_void_p(filter),)
  rval = TextFilter_Get.func(args[0])
  return str(rval.decode())

def TextFilter_IsActive(filter):
  if not hasattr(TextFilter_IsActive, 'func'):
    proc = rpr_getfp('ImGui_TextFilter_IsActive')
    TextFilter_IsActive.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(filter),)
  rval = TextFilter_IsActive.func(args[0])
  return rval

def TextFilter_PassFilter(filter, text):
  if not hasattr(TextFilter_PassFilter, 'func'):
    proc = rpr_getfp('ImGui_TextFilter_PassFilter')
    TextFilter_PassFilter.func = CFUNCTYPE(c_bool, c_void_p, c_char_p)(proc)
  args = (c_void_p(filter), rpr_packsc(text))
  rval = TextFilter_PassFilter.func(args[0], args[1])
  return rval

def TextFilter_Set(filter, filter_text):
  if not hasattr(TextFilter_Set, 'func'):
    proc = rpr_getfp('ImGui_TextFilter_Set')
    TextFilter_Set.func = CFUNCTYPE(None, c_void_p, c_char_p)(proc)
  args = (c_void_p(filter), rpr_packsc(filter_text))
  TextFilter_Set.func(args[0], args[1])

def CollapsingHeader(ctx, label, p_visibleInOutOptional = None, flagsInOptional = None):
  if not hasattr(CollapsingHeader, 'func'):
    proc = rpr_getfp('ImGui_CollapsingHeader')
    CollapsingHeader.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_bool(p_visibleInOutOptional) if p_visibleInOutOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = CollapsingHeader.func(args[0], args[1], byref(args[2]) if args[2] != None else None, byref(args[3]) if args[3] != None else None)
  return rval, int(args[2].value) if p_visibleInOutOptional != None else None

def GetTreeNodeToLabelSpacing(ctx):
  if not hasattr(GetTreeNodeToLabelSpacing, 'func'):
    proc = rpr_getfp('ImGui_GetTreeNodeToLabelSpacing')
    GetTreeNodeToLabelSpacing.func = CFUNCTYPE(c_double, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetTreeNodeToLabelSpacing.func(args[0])
  return rval

def IsItemToggledOpen(ctx):
  if not hasattr(IsItemToggledOpen, 'func'):
    proc = rpr_getfp('ImGui_IsItemToggledOpen')
    IsItemToggledOpen.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = IsItemToggledOpen.func(args[0])
  return rval

def SetNextItemOpen(ctx, is_open, condInOptional = None):
  if not hasattr(SetNextItemOpen, 'func'):
    proc = rpr_getfp('ImGui_SetNextItemOpen')
    SetNextItemOpen.func = CFUNCTYPE(None, c_void_p, c_bool, c_void_p)(proc)
  args = (c_void_p(ctx), c_bool(is_open), c_int(condInOptional) if condInOptional != None else None)
  SetNextItemOpen.func(args[0], args[1], byref(args[2]) if args[2] != None else None)

def TreeNode(ctx, label, flagsInOptional = None):
  if not hasattr(TreeNode, 'func'):
    proc = rpr_getfp('ImGui_TreeNode')
    TreeNode.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(label), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = TreeNode.func(args[0], args[1], byref(args[2]) if args[2] != None else None)
  return rval

def TreeNodeEx(ctx, str_id, label, flagsInOptional = None):
  if not hasattr(TreeNodeEx, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeEx')
    TreeNodeEx.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(str_id), rpr_packsc(label), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = TreeNodeEx.func(args[0], args[1], args[2], byref(args[3]) if args[3] != None else None)
  return rval

def TreePop(ctx):
  if not hasattr(TreePop, 'func'):
    proc = rpr_getfp('ImGui_TreePop')
    TreePop.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  TreePop.func(args[0])

def TreePush(ctx, str_id):
  if not hasattr(TreePush, 'func'):
    proc = rpr_getfp('ImGui_TreePush')
    TreePush.func = CFUNCTYPE(None, c_void_p, c_char_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(str_id))
  TreePush.func(args[0], args[1])

def TreeNodeFlags_AllowOverlap():
  if not hasattr(TreeNodeFlags_AllowOverlap, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_AllowOverlap')
    TreeNodeFlags_AllowOverlap.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_AllowOverlap, 'cache'):
    TreeNodeFlags_AllowOverlap.cache = TreeNodeFlags_AllowOverlap.func()
  return TreeNodeFlags_AllowOverlap.cache

def TreeNodeFlags_Bullet():
  if not hasattr(TreeNodeFlags_Bullet, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_Bullet')
    TreeNodeFlags_Bullet.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_Bullet, 'cache'):
    TreeNodeFlags_Bullet.cache = TreeNodeFlags_Bullet.func()
  return TreeNodeFlags_Bullet.cache

def TreeNodeFlags_CollapsingHeader():
  if not hasattr(TreeNodeFlags_CollapsingHeader, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_CollapsingHeader')
    TreeNodeFlags_CollapsingHeader.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_CollapsingHeader, 'cache'):
    TreeNodeFlags_CollapsingHeader.cache = TreeNodeFlags_CollapsingHeader.func()
  return TreeNodeFlags_CollapsingHeader.cache

def TreeNodeFlags_DefaultOpen():
  if not hasattr(TreeNodeFlags_DefaultOpen, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_DefaultOpen')
    TreeNodeFlags_DefaultOpen.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_DefaultOpen, 'cache'):
    TreeNodeFlags_DefaultOpen.cache = TreeNodeFlags_DefaultOpen.func()
  return TreeNodeFlags_DefaultOpen.cache

def TreeNodeFlags_DrawLinesFull():
  if not hasattr(TreeNodeFlags_DrawLinesFull, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_DrawLinesFull')
    TreeNodeFlags_DrawLinesFull.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_DrawLinesFull, 'cache'):
    TreeNodeFlags_DrawLinesFull.cache = TreeNodeFlags_DrawLinesFull.func()
  return TreeNodeFlags_DrawLinesFull.cache

def TreeNodeFlags_DrawLinesNone():
  if not hasattr(TreeNodeFlags_DrawLinesNone, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_DrawLinesNone')
    TreeNodeFlags_DrawLinesNone.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_DrawLinesNone, 'cache'):
    TreeNodeFlags_DrawLinesNone.cache = TreeNodeFlags_DrawLinesNone.func()
  return TreeNodeFlags_DrawLinesNone.cache

def TreeNodeFlags_DrawLinesToNodes():
  if not hasattr(TreeNodeFlags_DrawLinesToNodes, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_DrawLinesToNodes')
    TreeNodeFlags_DrawLinesToNodes.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_DrawLinesToNodes, 'cache'):
    TreeNodeFlags_DrawLinesToNodes.cache = TreeNodeFlags_DrawLinesToNodes.func()
  return TreeNodeFlags_DrawLinesToNodes.cache

def TreeNodeFlags_FramePadding():
  if not hasattr(TreeNodeFlags_FramePadding, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_FramePadding')
    TreeNodeFlags_FramePadding.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_FramePadding, 'cache'):
    TreeNodeFlags_FramePadding.cache = TreeNodeFlags_FramePadding.func()
  return TreeNodeFlags_FramePadding.cache

def TreeNodeFlags_Framed():
  if not hasattr(TreeNodeFlags_Framed, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_Framed')
    TreeNodeFlags_Framed.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_Framed, 'cache'):
    TreeNodeFlags_Framed.cache = TreeNodeFlags_Framed.func()
  return TreeNodeFlags_Framed.cache

def TreeNodeFlags_LabelSpanAllColumns():
  if not hasattr(TreeNodeFlags_LabelSpanAllColumns, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_LabelSpanAllColumns')
    TreeNodeFlags_LabelSpanAllColumns.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_LabelSpanAllColumns, 'cache'):
    TreeNodeFlags_LabelSpanAllColumns.cache = TreeNodeFlags_LabelSpanAllColumns.func()
  return TreeNodeFlags_LabelSpanAllColumns.cache

def TreeNodeFlags_Leaf():
  if not hasattr(TreeNodeFlags_Leaf, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_Leaf')
    TreeNodeFlags_Leaf.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_Leaf, 'cache'):
    TreeNodeFlags_Leaf.cache = TreeNodeFlags_Leaf.func()
  return TreeNodeFlags_Leaf.cache

def TreeNodeFlags_NavLeftJumpsToParent():
  if not hasattr(TreeNodeFlags_NavLeftJumpsToParent, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_NavLeftJumpsToParent')
    TreeNodeFlags_NavLeftJumpsToParent.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_NavLeftJumpsToParent, 'cache'):
    TreeNodeFlags_NavLeftJumpsToParent.cache = TreeNodeFlags_NavLeftJumpsToParent.func()
  return TreeNodeFlags_NavLeftJumpsToParent.cache

def TreeNodeFlags_NoAutoOpenOnLog():
  if not hasattr(TreeNodeFlags_NoAutoOpenOnLog, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_NoAutoOpenOnLog')
    TreeNodeFlags_NoAutoOpenOnLog.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_NoAutoOpenOnLog, 'cache'):
    TreeNodeFlags_NoAutoOpenOnLog.cache = TreeNodeFlags_NoAutoOpenOnLog.func()
  return TreeNodeFlags_NoAutoOpenOnLog.cache

def TreeNodeFlags_NoTreePushOnOpen():
  if not hasattr(TreeNodeFlags_NoTreePushOnOpen, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_NoTreePushOnOpen')
    TreeNodeFlags_NoTreePushOnOpen.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_NoTreePushOnOpen, 'cache'):
    TreeNodeFlags_NoTreePushOnOpen.cache = TreeNodeFlags_NoTreePushOnOpen.func()
  return TreeNodeFlags_NoTreePushOnOpen.cache

def TreeNodeFlags_None():
  if not hasattr(TreeNodeFlags_None, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_None')
    TreeNodeFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_None, 'cache'):
    TreeNodeFlags_None.cache = TreeNodeFlags_None.func()
  return TreeNodeFlags_None.cache

def TreeNodeFlags_OpenOnArrow():
  if not hasattr(TreeNodeFlags_OpenOnArrow, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_OpenOnArrow')
    TreeNodeFlags_OpenOnArrow.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_OpenOnArrow, 'cache'):
    TreeNodeFlags_OpenOnArrow.cache = TreeNodeFlags_OpenOnArrow.func()
  return TreeNodeFlags_OpenOnArrow.cache

def TreeNodeFlags_OpenOnDoubleClick():
  if not hasattr(TreeNodeFlags_OpenOnDoubleClick, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_OpenOnDoubleClick')
    TreeNodeFlags_OpenOnDoubleClick.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_OpenOnDoubleClick, 'cache'):
    TreeNodeFlags_OpenOnDoubleClick.cache = TreeNodeFlags_OpenOnDoubleClick.func()
  return TreeNodeFlags_OpenOnDoubleClick.cache

def TreeNodeFlags_Selected():
  if not hasattr(TreeNodeFlags_Selected, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_Selected')
    TreeNodeFlags_Selected.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_Selected, 'cache'):
    TreeNodeFlags_Selected.cache = TreeNodeFlags_Selected.func()
  return TreeNodeFlags_Selected.cache

def TreeNodeFlags_SpanAllColumns():
  if not hasattr(TreeNodeFlags_SpanAllColumns, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_SpanAllColumns')
    TreeNodeFlags_SpanAllColumns.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_SpanAllColumns, 'cache'):
    TreeNodeFlags_SpanAllColumns.cache = TreeNodeFlags_SpanAllColumns.func()
  return TreeNodeFlags_SpanAllColumns.cache

def TreeNodeFlags_SpanAvailWidth():
  if not hasattr(TreeNodeFlags_SpanAvailWidth, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_SpanAvailWidth')
    TreeNodeFlags_SpanAvailWidth.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_SpanAvailWidth, 'cache'):
    TreeNodeFlags_SpanAvailWidth.cache = TreeNodeFlags_SpanAvailWidth.func()
  return TreeNodeFlags_SpanAvailWidth.cache

def TreeNodeFlags_SpanFullWidth():
  if not hasattr(TreeNodeFlags_SpanFullWidth, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_SpanFullWidth')
    TreeNodeFlags_SpanFullWidth.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_SpanFullWidth, 'cache'):
    TreeNodeFlags_SpanFullWidth.cache = TreeNodeFlags_SpanFullWidth.func()
  return TreeNodeFlags_SpanFullWidth.cache

def TreeNodeFlags_SpanLabelWidth():
  if not hasattr(TreeNodeFlags_SpanLabelWidth, 'func'):
    proc = rpr_getfp('ImGui_TreeNodeFlags_SpanLabelWidth')
    TreeNodeFlags_SpanLabelWidth.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(TreeNodeFlags_SpanLabelWidth, 'cache'):
    TreeNodeFlags_SpanLabelWidth.cache = TreeNodeFlags_SpanLabelWidth.func()
  return TreeNodeFlags_SpanLabelWidth.cache

def GetBuiltinPath():
  if not hasattr(GetBuiltinPath, 'func'):
    proc = rpr_getfp('ImGui_GetBuiltinPath')
    GetBuiltinPath.func = CFUNCTYPE(c_char_p)(proc)
  rval = GetBuiltinPath.func()
  return str(rval.decode())

def GetVersion():
  if not hasattr(GetVersion, 'func'):
    proc = rpr_getfp('ImGui_GetVersion')
    GetVersion.func = CFUNCTYPE(None, c_char_p, c_int, c_void_p, c_char_p, c_int)(proc)
  args = (rpr_packs(0), c_int(1024), c_int(0), rpr_packs(0), c_int(1024))
  GetVersion.func(args[0], args[1], byref(args[2]), args[3], args[4])
  return rpr_unpacks(args[0]), int(args[2].value), rpr_unpacks(args[3])

def NumericLimits_Double():
  if not hasattr(NumericLimits_Double, 'func'):
    proc = rpr_getfp('ImGui_NumericLimits_Double')
    NumericLimits_Double.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_double(0), c_double(0))
  NumericLimits_Double.func(byref(args[0]), byref(args[1]))
  return float(args[0].value), float(args[1].value)

def NumericLimits_Float():
  if not hasattr(NumericLimits_Float, 'func'):
    proc = rpr_getfp('ImGui_NumericLimits_Float')
    NumericLimits_Float.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_double(0), c_double(0))
  NumericLimits_Float.func(byref(args[0]), byref(args[1]))
  return float(args[0].value), float(args[1].value)

def NumericLimits_Int():
  if not hasattr(NumericLimits_Int, 'func'):
    proc = rpr_getfp('ImGui_NumericLimits_Int')
    NumericLimits_Int.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_int(0), c_int(0))
  NumericLimits_Int.func(byref(args[0]), byref(args[1]))
  return int(args[0].value), int(args[1].value)

def PointConvertNative(ctx, xInOut, yInOut, to_nativeInOptional = None):
  if not hasattr(PointConvertNative, 'func'):
    proc = rpr_getfp('ImGui_PointConvertNative')
    PointConvertNative.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(xInOut), c_double(yInOut), c_bool(to_nativeInOptional) if to_nativeInOptional != None else None)
  PointConvertNative.func(args[0], byref(args[1]), byref(args[2]), byref(args[3]) if args[3] != None else None)
  return float(args[1].value), float(args[2].value)

def ProgressBar(ctx, fraction, size_arg_wInOptional = None, size_arg_hInOptional = None, overlayInOptional = None):
  if not hasattr(ProgressBar, 'func'):
    proc = rpr_getfp('ImGui_ProgressBar')
    ProgressBar.func = CFUNCTYPE(None, c_void_p, c_double, c_void_p, c_void_p, c_char_p)(proc)
  args = (c_void_p(ctx), c_double(fraction), c_double(size_arg_wInOptional) if size_arg_wInOptional != None else None, c_double(size_arg_hInOptional) if size_arg_hInOptional != None else None, rpr_packsc(overlayInOptional) if overlayInOptional != None else None)
  ProgressBar.func(args[0], args[1], byref(args[2]) if args[2] != None else None, byref(args[3]) if args[3] != None else None, args[4])

def ValidatePtr(pointer, type):
  if not hasattr(ValidatePtr, 'func'):
    proc = rpr_getfp('ImGui_ValidatePtr')
    ValidatePtr.func = CFUNCTYPE(c_bool, c_void_p, c_char_p)(proc)
  args = (c_void_p(pointer), rpr_packsc(type))
  rval = ValidatePtr.func(args[0], args[1])
  return rval

def GetClipboardText(ctx):
  if not hasattr(GetClipboardText, 'func'):
    proc = rpr_getfp('ImGui_GetClipboardText')
    GetClipboardText.func = CFUNCTYPE(c_char_p, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetClipboardText.func(args[0])
  return str(rval.decode())

def SetClipboardText(ctx, text):
  if not hasattr(SetClipboardText, 'func'):
    proc = rpr_getfp('ImGui_SetClipboardText')
    SetClipboardText.func = CFUNCTYPE(None, c_void_p, c_char_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(text))
  SetClipboardText.func(args[0], args[1])

def ColorConvertDouble4ToU32(r, g, b, a):
  if not hasattr(ColorConvertDouble4ToU32, 'func'):
    proc = rpr_getfp('ImGui_ColorConvertDouble4ToU32')
    ColorConvertDouble4ToU32.func = CFUNCTYPE(c_int, c_double, c_double, c_double, c_double)(proc)
  args = (c_double(r), c_double(g), c_double(b), c_double(a))
  rval = ColorConvertDouble4ToU32.func(args[0], args[1], args[2], args[3])
  return rval

def ColorConvertHSVtoRGB(h, s, v):
  if not hasattr(ColorConvertHSVtoRGB, 'func'):
    proc = rpr_getfp('ImGui_ColorConvertHSVtoRGB')
    ColorConvertHSVtoRGB.func = CFUNCTYPE(None, c_double, c_double, c_double, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_double(h), c_double(s), c_double(v), c_double(0), c_double(0), c_double(0))
  ColorConvertHSVtoRGB.func(args[0], args[1], args[2], byref(args[3]), byref(args[4]), byref(args[5]))
  return float(args[3].value), float(args[4].value), float(args[5].value)

def ColorConvertNative(rgb):
  if not hasattr(ColorConvertNative, 'func'):
    proc = rpr_getfp('ImGui_ColorConvertNative')
    ColorConvertNative.func = CFUNCTYPE(c_int, c_int)(proc)
  args = (c_int(rgb),)
  rval = ColorConvertNative.func(args[0])
  return rval

def ColorConvertRGBtoHSV(r, g, b):
  if not hasattr(ColorConvertRGBtoHSV, 'func'):
    proc = rpr_getfp('ImGui_ColorConvertRGBtoHSV')
    ColorConvertRGBtoHSV.func = CFUNCTYPE(None, c_double, c_double, c_double, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_double(r), c_double(g), c_double(b), c_double(0), c_double(0), c_double(0))
  ColorConvertRGBtoHSV.func(args[0], args[1], args[2], byref(args[3]), byref(args[4]), byref(args[5]))
  return float(args[3].value), float(args[4].value), float(args[5].value)

def ColorConvertU32ToDouble4(rgba):
  if not hasattr(ColorConvertU32ToDouble4, 'func'):
    proc = rpr_getfp('ImGui_ColorConvertU32ToDouble4')
    ColorConvertU32ToDouble4.func = CFUNCTYPE(None, c_int, c_void_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_int(rgba), c_double(0), c_double(0), c_double(0), c_double(0))
  ColorConvertU32ToDouble4.func(args[0], byref(args[1]), byref(args[2]), byref(args[3]), byref(args[4]))
  return float(args[1].value), float(args[2].value), float(args[3].value), float(args[4].value)

def Cond_Always():
  if not hasattr(Cond_Always, 'func'):
    proc = rpr_getfp('ImGui_Cond_Always')
    Cond_Always.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Cond_Always, 'cache'):
    Cond_Always.cache = Cond_Always.func()
  return Cond_Always.cache

def Cond_Appearing():
  if not hasattr(Cond_Appearing, 'func'):
    proc = rpr_getfp('ImGui_Cond_Appearing')
    Cond_Appearing.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Cond_Appearing, 'cache'):
    Cond_Appearing.cache = Cond_Appearing.func()
  return Cond_Appearing.cache

def Cond_FirstUseEver():
  if not hasattr(Cond_FirstUseEver, 'func'):
    proc = rpr_getfp('ImGui_Cond_FirstUseEver')
    Cond_FirstUseEver.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Cond_FirstUseEver, 'cache'):
    Cond_FirstUseEver.cache = Cond_FirstUseEver.func()
  return Cond_FirstUseEver.cache

def Cond_Once():
  if not hasattr(Cond_Once, 'func'):
    proc = rpr_getfp('ImGui_Cond_Once')
    Cond_Once.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(Cond_Once, 'cache'):
    Cond_Once.cache = Cond_Once.func()
  return Cond_Once.cache

def PopID(ctx):
  if not hasattr(PopID, 'func'):
    proc = rpr_getfp('ImGui_PopID')
    PopID.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  PopID.func(args[0])

def PushID(ctx, str_id):
  if not hasattr(PushID, 'func'):
    proc = rpr_getfp('ImGui_PushID')
    PushID.func = CFUNCTYPE(None, c_void_p, c_char_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(str_id))
  PushID.func(args[0], args[1])

def DebugLog(ctx, text):
  if not hasattr(DebugLog, 'func'):
    proc = rpr_getfp('ImGui_DebugLog')
    DebugLog.func = CFUNCTYPE(None, c_void_p, c_char_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(text))
  DebugLog.func(args[0], args[1])

def LogFinish(ctx):
  if not hasattr(LogFinish, 'func'):
    proc = rpr_getfp('ImGui_LogFinish')
    LogFinish.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  LogFinish.func(args[0])

def LogText(ctx, text):
  if not hasattr(LogText, 'func'):
    proc = rpr_getfp('ImGui_LogText')
    LogText.func = CFUNCTYPE(None, c_void_p, c_char_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(text))
  LogText.func(args[0], args[1])

def LogToClipboard(ctx, auto_open_depthInOptional = None):
  if not hasattr(LogToClipboard, 'func'):
    proc = rpr_getfp('ImGui_LogToClipboard')
    LogToClipboard.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(auto_open_depthInOptional) if auto_open_depthInOptional != None else None)
  LogToClipboard.func(args[0], byref(args[1]) if args[1] != None else None)

def LogToFile(ctx, auto_open_depthInOptional = None, filenameInOptional = None):
  if not hasattr(LogToFile, 'func'):
    proc = rpr_getfp('ImGui_LogToFile')
    LogToFile.func = CFUNCTYPE(None, c_void_p, c_void_p, c_char_p)(proc)
  args = (c_void_p(ctx), c_int(auto_open_depthInOptional) if auto_open_depthInOptional != None else None, rpr_packsc(filenameInOptional) if filenameInOptional != None else None)
  LogToFile.func(args[0], byref(args[1]) if args[1] != None else None, args[2])

def LogToTTY(ctx, auto_open_depthInOptional = None):
  if not hasattr(LogToTTY, 'func'):
    proc = rpr_getfp('ImGui_LogToTTY')
    LogToTTY.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(auto_open_depthInOptional) if auto_open_depthInOptional != None else None)
  LogToTTY.func(args[0], byref(args[1]) if args[1] != None else None)

def GetMainViewport(ctx):
  if not hasattr(GetMainViewport, 'func'):
    proc = rpr_getfp('ImGui_GetMainViewport')
    GetMainViewport.func = CFUNCTYPE(c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetMainViewport.func(args[0])
  return rval

def GetWindowViewport(ctx):
  if not hasattr(GetWindowViewport, 'func'):
    proc = rpr_getfp('ImGui_GetWindowViewport')
    GetWindowViewport.func = CFUNCTYPE(c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetWindowViewport.func(args[0])
  return rval

def Viewport_GetCenter(viewport):
  if not hasattr(Viewport_GetCenter, 'func'):
    proc = rpr_getfp('ImGui_Viewport_GetCenter')
    Viewport_GetCenter.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(viewport), c_double(0), c_double(0))
  Viewport_GetCenter.func(args[0], byref(args[1]), byref(args[2]))
  return float(args[1].value), float(args[2].value)

def Viewport_GetPos(viewport):
  if not hasattr(Viewport_GetPos, 'func'):
    proc = rpr_getfp('ImGui_Viewport_GetPos')
    Viewport_GetPos.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(viewport), c_double(0), c_double(0))
  Viewport_GetPos.func(args[0], byref(args[1]), byref(args[2]))
  return float(args[1].value), float(args[2].value)

def Viewport_GetSize(viewport):
  if not hasattr(Viewport_GetSize, 'func'):
    proc = rpr_getfp('ImGui_Viewport_GetSize')
    Viewport_GetSize.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(viewport), c_double(0), c_double(0))
  Viewport_GetSize.func(args[0], byref(args[1]), byref(args[2]))
  return float(args[1].value), float(args[2].value)

def Viewport_GetWorkCenter(viewport):
  if not hasattr(Viewport_GetWorkCenter, 'func'):
    proc = rpr_getfp('ImGui_Viewport_GetWorkCenter')
    Viewport_GetWorkCenter.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(viewport), c_double(0), c_double(0))
  Viewport_GetWorkCenter.func(args[0], byref(args[1]), byref(args[2]))
  return float(args[1].value), float(args[2].value)

def Viewport_GetWorkPos(viewport):
  if not hasattr(Viewport_GetWorkPos, 'func'):
    proc = rpr_getfp('ImGui_Viewport_GetWorkPos')
    Viewport_GetWorkPos.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(viewport), c_double(0), c_double(0))
  Viewport_GetWorkPos.func(args[0], byref(args[1]), byref(args[2]))
  return float(args[1].value), float(args[2].value)

def Viewport_GetWorkSize(viewport):
  if not hasattr(Viewport_GetWorkSize, 'func'):
    proc = rpr_getfp('ImGui_Viewport_GetWorkSize')
    Viewport_GetWorkSize.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(viewport), c_double(0), c_double(0))
  Viewport_GetWorkSize.func(args[0], byref(args[1]), byref(args[2]))
  return float(args[1].value), float(args[2].value)

def Begin(ctx, name, p_openInOutOptional = None, flagsInOptional = None):
  if not hasattr(Begin, 'func'):
    proc = rpr_getfp('ImGui_Begin')
    Begin.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(name), c_bool(p_openInOutOptional) if p_openInOutOptional != None else None, c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = Begin.func(args[0], args[1], byref(args[2]) if args[2] != None else None, byref(args[3]) if args[3] != None else None)
  return rval, int(args[2].value) if p_openInOutOptional != None else None

def End(ctx):
  if not hasattr(End, 'func'):
    proc = rpr_getfp('ImGui_End')
    End.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  End.func(args[0])

def BeginChild(ctx, str_id, size_wInOptional = None, size_hInOptional = None, child_flagsInOptional = None, window_flagsInOptional = None):
  if not hasattr(BeginChild, 'func'):
    proc = rpr_getfp('ImGui_BeginChild')
    BeginChild.func = CFUNCTYPE(c_bool, c_void_p, c_char_p, c_void_p, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(str_id), c_double(size_wInOptional) if size_wInOptional != None else None, c_double(size_hInOptional) if size_hInOptional != None else None, c_int(child_flagsInOptional) if child_flagsInOptional != None else None, c_int(window_flagsInOptional) if window_flagsInOptional != None else None)
  rval = BeginChild.func(args[0], args[1], byref(args[2]) if args[2] != None else None, byref(args[3]) if args[3] != None else None, byref(args[4]) if args[4] != None else None, byref(args[5]) if args[5] != None else None)
  return rval

def EndChild(ctx):
  if not hasattr(EndChild, 'func'):
    proc = rpr_getfp('ImGui_EndChild')
    EndChild.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  EndChild.func(args[0])

def ChildFlags_AlwaysAutoResize():
  if not hasattr(ChildFlags_AlwaysAutoResize, 'func'):
    proc = rpr_getfp('ImGui_ChildFlags_AlwaysAutoResize')
    ChildFlags_AlwaysAutoResize.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ChildFlags_AlwaysAutoResize, 'cache'):
    ChildFlags_AlwaysAutoResize.cache = ChildFlags_AlwaysAutoResize.func()
  return ChildFlags_AlwaysAutoResize.cache

def ChildFlags_AlwaysUseWindowPadding():
  if not hasattr(ChildFlags_AlwaysUseWindowPadding, 'func'):
    proc = rpr_getfp('ImGui_ChildFlags_AlwaysUseWindowPadding')
    ChildFlags_AlwaysUseWindowPadding.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ChildFlags_AlwaysUseWindowPadding, 'cache'):
    ChildFlags_AlwaysUseWindowPadding.cache = ChildFlags_AlwaysUseWindowPadding.func()
  return ChildFlags_AlwaysUseWindowPadding.cache

def ChildFlags_AutoResizeX():
  if not hasattr(ChildFlags_AutoResizeX, 'func'):
    proc = rpr_getfp('ImGui_ChildFlags_AutoResizeX')
    ChildFlags_AutoResizeX.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ChildFlags_AutoResizeX, 'cache'):
    ChildFlags_AutoResizeX.cache = ChildFlags_AutoResizeX.func()
  return ChildFlags_AutoResizeX.cache

def ChildFlags_AutoResizeY():
  if not hasattr(ChildFlags_AutoResizeY, 'func'):
    proc = rpr_getfp('ImGui_ChildFlags_AutoResizeY')
    ChildFlags_AutoResizeY.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ChildFlags_AutoResizeY, 'cache'):
    ChildFlags_AutoResizeY.cache = ChildFlags_AutoResizeY.func()
  return ChildFlags_AutoResizeY.cache

def ChildFlags_Borders():
  if not hasattr(ChildFlags_Borders, 'func'):
    proc = rpr_getfp('ImGui_ChildFlags_Borders')
    ChildFlags_Borders.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ChildFlags_Borders, 'cache'):
    ChildFlags_Borders.cache = ChildFlags_Borders.func()
  return ChildFlags_Borders.cache

def ChildFlags_FrameStyle():
  if not hasattr(ChildFlags_FrameStyle, 'func'):
    proc = rpr_getfp('ImGui_ChildFlags_FrameStyle')
    ChildFlags_FrameStyle.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ChildFlags_FrameStyle, 'cache'):
    ChildFlags_FrameStyle.cache = ChildFlags_FrameStyle.func()
  return ChildFlags_FrameStyle.cache

def ChildFlags_NavFlattened():
  if not hasattr(ChildFlags_NavFlattened, 'func'):
    proc = rpr_getfp('ImGui_ChildFlags_NavFlattened')
    ChildFlags_NavFlattened.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ChildFlags_NavFlattened, 'cache'):
    ChildFlags_NavFlattened.cache = ChildFlags_NavFlattened.func()
  return ChildFlags_NavFlattened.cache

def ChildFlags_None():
  if not hasattr(ChildFlags_None, 'func'):
    proc = rpr_getfp('ImGui_ChildFlags_None')
    ChildFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ChildFlags_None, 'cache'):
    ChildFlags_None.cache = ChildFlags_None.func()
  return ChildFlags_None.cache

def ChildFlags_ResizeX():
  if not hasattr(ChildFlags_ResizeX, 'func'):
    proc = rpr_getfp('ImGui_ChildFlags_ResizeX')
    ChildFlags_ResizeX.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ChildFlags_ResizeX, 'cache'):
    ChildFlags_ResizeX.cache = ChildFlags_ResizeX.func()
  return ChildFlags_ResizeX.cache

def ChildFlags_ResizeY():
  if not hasattr(ChildFlags_ResizeY, 'func'):
    proc = rpr_getfp('ImGui_ChildFlags_ResizeY')
    ChildFlags_ResizeY.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(ChildFlags_ResizeY, 'cache'):
    ChildFlags_ResizeY.cache = ChildFlags_ResizeY.func()
  return ChildFlags_ResizeY.cache

def ShowAboutWindow(ctx, p_openInOutOptional = None):
  if not hasattr(ShowAboutWindow, 'func'):
    proc = rpr_getfp('ImGui_ShowAboutWindow')
    ShowAboutWindow.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_bool(p_openInOutOptional) if p_openInOutOptional != None else None)
  ShowAboutWindow.func(args[0], byref(args[1]) if args[1] != None else None)
  return int(args[1].value) if p_openInOutOptional != None else None

def ShowDebugLogWindow(ctx, p_openInOutOptional = None):
  if not hasattr(ShowDebugLogWindow, 'func'):
    proc = rpr_getfp('ImGui_ShowDebugLogWindow')
    ShowDebugLogWindow.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_bool(p_openInOutOptional) if p_openInOutOptional != None else None)
  ShowDebugLogWindow.func(args[0], byref(args[1]) if args[1] != None else None)
  return int(args[1].value) if p_openInOutOptional != None else None

def ShowIDStackToolWindow(ctx, p_openInOutOptional = None):
  if not hasattr(ShowIDStackToolWindow, 'func'):
    proc = rpr_getfp('ImGui_ShowIDStackToolWindow')
    ShowIDStackToolWindow.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_bool(p_openInOutOptional) if p_openInOutOptional != None else None)
  ShowIDStackToolWindow.func(args[0], byref(args[1]) if args[1] != None else None)
  return int(args[1].value) if p_openInOutOptional != None else None

def ShowMetricsWindow(ctx, p_openInOutOptional = None):
  if not hasattr(ShowMetricsWindow, 'func'):
    proc = rpr_getfp('ImGui_ShowMetricsWindow')
    ShowMetricsWindow.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_bool(p_openInOutOptional) if p_openInOutOptional != None else None)
  ShowMetricsWindow.func(args[0], byref(args[1]) if args[1] != None else None)
  return int(args[1].value) if p_openInOutOptional != None else None

def GetWindowDockID(ctx):
  if not hasattr(GetWindowDockID, 'func'):
    proc = rpr_getfp('ImGui_GetWindowDockID')
    GetWindowDockID.func = CFUNCTYPE(c_int, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetWindowDockID.func(args[0])
  return rval

def IsWindowDocked(ctx):
  if not hasattr(IsWindowDocked, 'func'):
    proc = rpr_getfp('ImGui_IsWindowDocked')
    IsWindowDocked.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = IsWindowDocked.func(args[0])
  return rval

def SetNextWindowDockID(ctx, dock_id, condInOptional = None):
  if not hasattr(SetNextWindowDockID, 'func'):
    proc = rpr_getfp('ImGui_SetNextWindowDockID')
    SetNextWindowDockID.func = CFUNCTYPE(None, c_void_p, c_int, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(dock_id), c_int(condInOptional) if condInOptional != None else None)
  SetNextWindowDockID.func(args[0], args[1], byref(args[2]) if args[2] != None else None)

def WindowFlags_AlwaysAutoResize():
  if not hasattr(WindowFlags_AlwaysAutoResize, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_AlwaysAutoResize')
    WindowFlags_AlwaysAutoResize.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_AlwaysAutoResize, 'cache'):
    WindowFlags_AlwaysAutoResize.cache = WindowFlags_AlwaysAutoResize.func()
  return WindowFlags_AlwaysAutoResize.cache

def WindowFlags_AlwaysHorizontalScrollbar():
  if not hasattr(WindowFlags_AlwaysHorizontalScrollbar, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_AlwaysHorizontalScrollbar')
    WindowFlags_AlwaysHorizontalScrollbar.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_AlwaysHorizontalScrollbar, 'cache'):
    WindowFlags_AlwaysHorizontalScrollbar.cache = WindowFlags_AlwaysHorizontalScrollbar.func()
  return WindowFlags_AlwaysHorizontalScrollbar.cache

def WindowFlags_AlwaysVerticalScrollbar():
  if not hasattr(WindowFlags_AlwaysVerticalScrollbar, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_AlwaysVerticalScrollbar')
    WindowFlags_AlwaysVerticalScrollbar.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_AlwaysVerticalScrollbar, 'cache'):
    WindowFlags_AlwaysVerticalScrollbar.cache = WindowFlags_AlwaysVerticalScrollbar.func()
  return WindowFlags_AlwaysVerticalScrollbar.cache

def WindowFlags_HorizontalScrollbar():
  if not hasattr(WindowFlags_HorizontalScrollbar, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_HorizontalScrollbar')
    WindowFlags_HorizontalScrollbar.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_HorizontalScrollbar, 'cache'):
    WindowFlags_HorizontalScrollbar.cache = WindowFlags_HorizontalScrollbar.func()
  return WindowFlags_HorizontalScrollbar.cache

def WindowFlags_MenuBar():
  if not hasattr(WindowFlags_MenuBar, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_MenuBar')
    WindowFlags_MenuBar.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_MenuBar, 'cache'):
    WindowFlags_MenuBar.cache = WindowFlags_MenuBar.func()
  return WindowFlags_MenuBar.cache

def WindowFlags_NoBackground():
  if not hasattr(WindowFlags_NoBackground, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_NoBackground')
    WindowFlags_NoBackground.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_NoBackground, 'cache'):
    WindowFlags_NoBackground.cache = WindowFlags_NoBackground.func()
  return WindowFlags_NoBackground.cache

def WindowFlags_NoCollapse():
  if not hasattr(WindowFlags_NoCollapse, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_NoCollapse')
    WindowFlags_NoCollapse.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_NoCollapse, 'cache'):
    WindowFlags_NoCollapse.cache = WindowFlags_NoCollapse.func()
  return WindowFlags_NoCollapse.cache

def WindowFlags_NoDecoration():
  if not hasattr(WindowFlags_NoDecoration, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_NoDecoration')
    WindowFlags_NoDecoration.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_NoDecoration, 'cache'):
    WindowFlags_NoDecoration.cache = WindowFlags_NoDecoration.func()
  return WindowFlags_NoDecoration.cache

def WindowFlags_NoDocking():
  if not hasattr(WindowFlags_NoDocking, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_NoDocking')
    WindowFlags_NoDocking.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_NoDocking, 'cache'):
    WindowFlags_NoDocking.cache = WindowFlags_NoDocking.func()
  return WindowFlags_NoDocking.cache

def WindowFlags_NoFocusOnAppearing():
  if not hasattr(WindowFlags_NoFocusOnAppearing, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_NoFocusOnAppearing')
    WindowFlags_NoFocusOnAppearing.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_NoFocusOnAppearing, 'cache'):
    WindowFlags_NoFocusOnAppearing.cache = WindowFlags_NoFocusOnAppearing.func()
  return WindowFlags_NoFocusOnAppearing.cache

def WindowFlags_NoInputs():
  if not hasattr(WindowFlags_NoInputs, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_NoInputs')
    WindowFlags_NoInputs.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_NoInputs, 'cache'):
    WindowFlags_NoInputs.cache = WindowFlags_NoInputs.func()
  return WindowFlags_NoInputs.cache

def WindowFlags_NoMouseInputs():
  if not hasattr(WindowFlags_NoMouseInputs, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_NoMouseInputs')
    WindowFlags_NoMouseInputs.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_NoMouseInputs, 'cache'):
    WindowFlags_NoMouseInputs.cache = WindowFlags_NoMouseInputs.func()
  return WindowFlags_NoMouseInputs.cache

def WindowFlags_NoMove():
  if not hasattr(WindowFlags_NoMove, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_NoMove')
    WindowFlags_NoMove.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_NoMove, 'cache'):
    WindowFlags_NoMove.cache = WindowFlags_NoMove.func()
  return WindowFlags_NoMove.cache

def WindowFlags_NoNav():
  if not hasattr(WindowFlags_NoNav, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_NoNav')
    WindowFlags_NoNav.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_NoNav, 'cache'):
    WindowFlags_NoNav.cache = WindowFlags_NoNav.func()
  return WindowFlags_NoNav.cache

def WindowFlags_NoNavFocus():
  if not hasattr(WindowFlags_NoNavFocus, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_NoNavFocus')
    WindowFlags_NoNavFocus.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_NoNavFocus, 'cache'):
    WindowFlags_NoNavFocus.cache = WindowFlags_NoNavFocus.func()
  return WindowFlags_NoNavFocus.cache

def WindowFlags_NoNavInputs():
  if not hasattr(WindowFlags_NoNavInputs, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_NoNavInputs')
    WindowFlags_NoNavInputs.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_NoNavInputs, 'cache'):
    WindowFlags_NoNavInputs.cache = WindowFlags_NoNavInputs.func()
  return WindowFlags_NoNavInputs.cache

def WindowFlags_NoResize():
  if not hasattr(WindowFlags_NoResize, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_NoResize')
    WindowFlags_NoResize.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_NoResize, 'cache'):
    WindowFlags_NoResize.cache = WindowFlags_NoResize.func()
  return WindowFlags_NoResize.cache

def WindowFlags_NoSavedSettings():
  if not hasattr(WindowFlags_NoSavedSettings, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_NoSavedSettings')
    WindowFlags_NoSavedSettings.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_NoSavedSettings, 'cache'):
    WindowFlags_NoSavedSettings.cache = WindowFlags_NoSavedSettings.func()
  return WindowFlags_NoSavedSettings.cache

def WindowFlags_NoScrollWithMouse():
  if not hasattr(WindowFlags_NoScrollWithMouse, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_NoScrollWithMouse')
    WindowFlags_NoScrollWithMouse.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_NoScrollWithMouse, 'cache'):
    WindowFlags_NoScrollWithMouse.cache = WindowFlags_NoScrollWithMouse.func()
  return WindowFlags_NoScrollWithMouse.cache

def WindowFlags_NoScrollbar():
  if not hasattr(WindowFlags_NoScrollbar, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_NoScrollbar')
    WindowFlags_NoScrollbar.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_NoScrollbar, 'cache'):
    WindowFlags_NoScrollbar.cache = WindowFlags_NoScrollbar.func()
  return WindowFlags_NoScrollbar.cache

def WindowFlags_NoTitleBar():
  if not hasattr(WindowFlags_NoTitleBar, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_NoTitleBar')
    WindowFlags_NoTitleBar.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_NoTitleBar, 'cache'):
    WindowFlags_NoTitleBar.cache = WindowFlags_NoTitleBar.func()
  return WindowFlags_NoTitleBar.cache

def WindowFlags_None():
  if not hasattr(WindowFlags_None, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_None')
    WindowFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_None, 'cache'):
    WindowFlags_None.cache = WindowFlags_None.func()
  return WindowFlags_None.cache

def WindowFlags_TopMost():
  if not hasattr(WindowFlags_TopMost, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_TopMost')
    WindowFlags_TopMost.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_TopMost, 'cache'):
    WindowFlags_TopMost.cache = WindowFlags_TopMost.func()
  return WindowFlags_TopMost.cache

def WindowFlags_UnsavedDocument():
  if not hasattr(WindowFlags_UnsavedDocument, 'func'):
    proc = rpr_getfp('ImGui_WindowFlags_UnsavedDocument')
    WindowFlags_UnsavedDocument.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(WindowFlags_UnsavedDocument, 'cache'):
    WindowFlags_UnsavedDocument.cache = WindowFlags_UnsavedDocument.func()
  return WindowFlags_UnsavedDocument.cache

def GetWindowDpiScale(ctx):
  if not hasattr(GetWindowDpiScale, 'func'):
    proc = rpr_getfp('ImGui_GetWindowDpiScale')
    GetWindowDpiScale.func = CFUNCTYPE(c_double, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetWindowDpiScale.func(args[0])
  return rval

def GetWindowHeight(ctx):
  if not hasattr(GetWindowHeight, 'func'):
    proc = rpr_getfp('ImGui_GetWindowHeight')
    GetWindowHeight.func = CFUNCTYPE(c_double, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetWindowHeight.func(args[0])
  return rval

def GetWindowPos(ctx):
  if not hasattr(GetWindowPos, 'func'):
    proc = rpr_getfp('ImGui_GetWindowPos')
    GetWindowPos.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(0), c_double(0))
  GetWindowPos.func(args[0], byref(args[1]), byref(args[2]))
  return float(args[1].value), float(args[2].value)

def GetWindowSize(ctx):
  if not hasattr(GetWindowSize, 'func'):
    proc = rpr_getfp('ImGui_GetWindowSize')
    GetWindowSize.func = CFUNCTYPE(None, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(0), c_double(0))
  GetWindowSize.func(args[0], byref(args[1]), byref(args[2]))
  return float(args[1].value), float(args[2].value)

def GetWindowWidth(ctx):
  if not hasattr(GetWindowWidth, 'func'):
    proc = rpr_getfp('ImGui_GetWindowWidth')
    GetWindowWidth.func = CFUNCTYPE(c_double, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetWindowWidth.func(args[0])
  return rval

def IsWindowAppearing(ctx):
  if not hasattr(IsWindowAppearing, 'func'):
    proc = rpr_getfp('ImGui_IsWindowAppearing')
    IsWindowAppearing.func = CFUNCTYPE(c_bool, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = IsWindowAppearing.func(args[0])
  return rval

def IsWindowFocused(ctx, flagsInOptional = None):
  if not hasattr(IsWindowFocused, 'func'):
    proc = rpr_getfp('ImGui_IsWindowFocused')
    IsWindowFocused.func = CFUNCTYPE(c_bool, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = IsWindowFocused.func(args[0], byref(args[1]) if args[1] != None else None)
  return rval

def IsWindowHovered(ctx, flagsInOptional = None):
  if not hasattr(IsWindowHovered, 'func'):
    proc = rpr_getfp('ImGui_IsWindowHovered')
    IsWindowHovered.func = CFUNCTYPE(c_bool, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_int(flagsInOptional) if flagsInOptional != None else None)
  rval = IsWindowHovered.func(args[0], byref(args[1]) if args[1] != None else None)
  return rval

def SetNextWindowBgAlpha(ctx, alpha):
  if not hasattr(SetNextWindowBgAlpha, 'func'):
    proc = rpr_getfp('ImGui_SetNextWindowBgAlpha')
    SetNextWindowBgAlpha.func = CFUNCTYPE(None, c_void_p, c_double)(proc)
  args = (c_void_p(ctx), c_double(alpha))
  SetNextWindowBgAlpha.func(args[0], args[1])

def SetNextWindowCollapsed(ctx, collapsed, condInOptional = None):
  if not hasattr(SetNextWindowCollapsed, 'func'):
    proc = rpr_getfp('ImGui_SetNextWindowCollapsed')
    SetNextWindowCollapsed.func = CFUNCTYPE(None, c_void_p, c_bool, c_void_p)(proc)
  args = (c_void_p(ctx), c_bool(collapsed), c_int(condInOptional) if condInOptional != None else None)
  SetNextWindowCollapsed.func(args[0], args[1], byref(args[2]) if args[2] != None else None)

def SetNextWindowContentSize(ctx, size_w, size_h):
  if not hasattr(SetNextWindowContentSize, 'func'):
    proc = rpr_getfp('ImGui_SetNextWindowContentSize')
    SetNextWindowContentSize.func = CFUNCTYPE(None, c_void_p, c_double, c_double)(proc)
  args = (c_void_p(ctx), c_double(size_w), c_double(size_h))
  SetNextWindowContentSize.func(args[0], args[1], args[2])

def SetNextWindowFocus(ctx):
  if not hasattr(SetNextWindowFocus, 'func'):
    proc = rpr_getfp('ImGui_SetNextWindowFocus')
    SetNextWindowFocus.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  SetNextWindowFocus.func(args[0])

def SetNextWindowPos(ctx, pos_x, pos_y, condInOptional = None, pivot_xInOptional = None, pivot_yInOptional = None):
  if not hasattr(SetNextWindowPos, 'func'):
    proc = rpr_getfp('ImGui_SetNextWindowPos')
    SetNextWindowPos.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_void_p, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(pos_x), c_double(pos_y), c_int(condInOptional) if condInOptional != None else None, c_double(pivot_xInOptional) if pivot_xInOptional != None else None, c_double(pivot_yInOptional) if pivot_yInOptional != None else None)
  SetNextWindowPos.func(args[0], args[1], args[2], byref(args[3]) if args[3] != None else None, byref(args[4]) if args[4] != None else None, byref(args[5]) if args[5] != None else None)

def SetNextWindowScroll(ctx, scroll_x, scroll_y):
  if not hasattr(SetNextWindowScroll, 'func'):
    proc = rpr_getfp('ImGui_SetNextWindowScroll')
    SetNextWindowScroll.func = CFUNCTYPE(None, c_void_p, c_double, c_double)(proc)
  args = (c_void_p(ctx), c_double(scroll_x), c_double(scroll_y))
  SetNextWindowScroll.func(args[0], args[1], args[2])

def SetNextWindowSize(ctx, size_w, size_h, condInOptional = None):
  if not hasattr(SetNextWindowSize, 'func'):
    proc = rpr_getfp('ImGui_SetNextWindowSize')
    SetNextWindowSize.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(size_w), c_double(size_h), c_int(condInOptional) if condInOptional != None else None)
  SetNextWindowSize.func(args[0], args[1], args[2], byref(args[3]) if args[3] != None else None)

def SetNextWindowSizeConstraints(ctx, size_min_w, size_min_h, size_max_w, size_max_h, custom_callbackInOptional = None):
  if not hasattr(SetNextWindowSizeConstraints, 'func'):
    proc = rpr_getfp('ImGui_SetNextWindowSizeConstraints')
    SetNextWindowSizeConstraints.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_double, c_double, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(size_min_w), c_double(size_min_h), c_double(size_max_w), c_double(size_max_h), c_void_p(custom_callbackInOptional) if custom_callbackInOptional != None else None)
  SetNextWindowSizeConstraints.func(args[0], args[1], args[2], args[3], args[4], args[5])

def SetWindowCollapsed(ctx, collapsed, condInOptional = None):
  if not hasattr(SetWindowCollapsed, 'func'):
    proc = rpr_getfp('ImGui_SetWindowCollapsed')
    SetWindowCollapsed.func = CFUNCTYPE(None, c_void_p, c_bool, c_void_p)(proc)
  args = (c_void_p(ctx), c_bool(collapsed), c_int(condInOptional) if condInOptional != None else None)
  SetWindowCollapsed.func(args[0], args[1], byref(args[2]) if args[2] != None else None)

def SetWindowCollapsedEx(ctx, name, collapsed, condInOptional = None):
  if not hasattr(SetWindowCollapsedEx, 'func'):
    proc = rpr_getfp('ImGui_SetWindowCollapsedEx')
    SetWindowCollapsedEx.func = CFUNCTYPE(None, c_void_p, c_char_p, c_bool, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(name), c_bool(collapsed), c_int(condInOptional) if condInOptional != None else None)
  SetWindowCollapsedEx.func(args[0], args[1], args[2], byref(args[3]) if args[3] != None else None)

def SetWindowFocus(ctx):
  if not hasattr(SetWindowFocus, 'func'):
    proc = rpr_getfp('ImGui_SetWindowFocus')
    SetWindowFocus.func = CFUNCTYPE(None, c_void_p)(proc)
  args = (c_void_p(ctx),)
  SetWindowFocus.func(args[0])

def SetWindowFocusEx(ctx, name):
  if not hasattr(SetWindowFocusEx, 'func'):
    proc = rpr_getfp('ImGui_SetWindowFocusEx')
    SetWindowFocusEx.func = CFUNCTYPE(None, c_void_p, c_char_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(name))
  SetWindowFocusEx.func(args[0], args[1])

def SetWindowPos(ctx, pos_x, pos_y, condInOptional = None):
  if not hasattr(SetWindowPos, 'func'):
    proc = rpr_getfp('ImGui_SetWindowPos')
    SetWindowPos.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(pos_x), c_double(pos_y), c_int(condInOptional) if condInOptional != None else None)
  SetWindowPos.func(args[0], args[1], args[2], byref(args[3]) if args[3] != None else None)

def SetWindowPosEx(ctx, name, pos_x, pos_y, condInOptional = None):
  if not hasattr(SetWindowPosEx, 'func'):
    proc = rpr_getfp('ImGui_SetWindowPosEx')
    SetWindowPosEx.func = CFUNCTYPE(None, c_void_p, c_char_p, c_double, c_double, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(name), c_double(pos_x), c_double(pos_y), c_int(condInOptional) if condInOptional != None else None)
  SetWindowPosEx.func(args[0], args[1], args[2], args[3], byref(args[4]) if args[4] != None else None)

def SetWindowSize(ctx, size_w, size_h, condInOptional = None):
  if not hasattr(SetWindowSize, 'func'):
    proc = rpr_getfp('ImGui_SetWindowSize')
    SetWindowSize.func = CFUNCTYPE(None, c_void_p, c_double, c_double, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(size_w), c_double(size_h), c_int(condInOptional) if condInOptional != None else None)
  SetWindowSize.func(args[0], args[1], args[2], byref(args[3]) if args[3] != None else None)

def SetWindowSizeEx(ctx, name, size_w, size_h, condInOptional = None):
  if not hasattr(SetWindowSizeEx, 'func'):
    proc = rpr_getfp('ImGui_SetWindowSizeEx')
    SetWindowSizeEx.func = CFUNCTYPE(None, c_void_p, c_char_p, c_double, c_double, c_void_p)(proc)
  args = (c_void_p(ctx), rpr_packsc(name), c_double(size_w), c_double(size_h), c_int(condInOptional) if condInOptional != None else None)
  SetWindowSizeEx.func(args[0], args[1], args[2], args[3], byref(args[4]) if args[4] != None else None)

def FocusedFlags_AnyWindow():
  if not hasattr(FocusedFlags_AnyWindow, 'func'):
    proc = rpr_getfp('ImGui_FocusedFlags_AnyWindow')
    FocusedFlags_AnyWindow.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(FocusedFlags_AnyWindow, 'cache'):
    FocusedFlags_AnyWindow.cache = FocusedFlags_AnyWindow.func()
  return FocusedFlags_AnyWindow.cache

def FocusedFlags_ChildWindows():
  if not hasattr(FocusedFlags_ChildWindows, 'func'):
    proc = rpr_getfp('ImGui_FocusedFlags_ChildWindows')
    FocusedFlags_ChildWindows.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(FocusedFlags_ChildWindows, 'cache'):
    FocusedFlags_ChildWindows.cache = FocusedFlags_ChildWindows.func()
  return FocusedFlags_ChildWindows.cache

def FocusedFlags_DockHierarchy():
  if not hasattr(FocusedFlags_DockHierarchy, 'func'):
    proc = rpr_getfp('ImGui_FocusedFlags_DockHierarchy')
    FocusedFlags_DockHierarchy.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(FocusedFlags_DockHierarchy, 'cache'):
    FocusedFlags_DockHierarchy.cache = FocusedFlags_DockHierarchy.func()
  return FocusedFlags_DockHierarchy.cache

def FocusedFlags_NoPopupHierarchy():
  if not hasattr(FocusedFlags_NoPopupHierarchy, 'func'):
    proc = rpr_getfp('ImGui_FocusedFlags_NoPopupHierarchy')
    FocusedFlags_NoPopupHierarchy.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(FocusedFlags_NoPopupHierarchy, 'cache'):
    FocusedFlags_NoPopupHierarchy.cache = FocusedFlags_NoPopupHierarchy.func()
  return FocusedFlags_NoPopupHierarchy.cache

def FocusedFlags_None():
  if not hasattr(FocusedFlags_None, 'func'):
    proc = rpr_getfp('ImGui_FocusedFlags_None')
    FocusedFlags_None.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(FocusedFlags_None, 'cache'):
    FocusedFlags_None.cache = FocusedFlags_None.func()
  return FocusedFlags_None.cache

def FocusedFlags_RootAndChildWindows():
  if not hasattr(FocusedFlags_RootAndChildWindows, 'func'):
    proc = rpr_getfp('ImGui_FocusedFlags_RootAndChildWindows')
    FocusedFlags_RootAndChildWindows.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(FocusedFlags_RootAndChildWindows, 'cache'):
    FocusedFlags_RootAndChildWindows.cache = FocusedFlags_RootAndChildWindows.func()
  return FocusedFlags_RootAndChildWindows.cache

def FocusedFlags_RootWindow():
  if not hasattr(FocusedFlags_RootWindow, 'func'):
    proc = rpr_getfp('ImGui_FocusedFlags_RootWindow')
    FocusedFlags_RootWindow.func = CFUNCTYPE(c_int)(proc)
  if not hasattr(FocusedFlags_RootWindow, 'cache'):
    FocusedFlags_RootWindow.cache = FocusedFlags_RootWindow.func()
  return FocusedFlags_RootWindow.cache

def GetScrollMaxX(ctx):
  if not hasattr(GetScrollMaxX, 'func'):
    proc = rpr_getfp('ImGui_GetScrollMaxX')
    GetScrollMaxX.func = CFUNCTYPE(c_double, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetScrollMaxX.func(args[0])
  return rval

def GetScrollMaxY(ctx):
  if not hasattr(GetScrollMaxY, 'func'):
    proc = rpr_getfp('ImGui_GetScrollMaxY')
    GetScrollMaxY.func = CFUNCTYPE(c_double, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetScrollMaxY.func(args[0])
  return rval

def GetScrollX(ctx):
  if not hasattr(GetScrollX, 'func'):
    proc = rpr_getfp('ImGui_GetScrollX')
    GetScrollX.func = CFUNCTYPE(c_double, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetScrollX.func(args[0])
  return rval

def GetScrollY(ctx):
  if not hasattr(GetScrollY, 'func'):
    proc = rpr_getfp('ImGui_GetScrollY')
    GetScrollY.func = CFUNCTYPE(c_double, c_void_p)(proc)
  args = (c_void_p(ctx),)
  rval = GetScrollY.func(args[0])
  return rval

def SetScrollFromPosX(ctx, local_x, center_x_ratioInOptional = None):
  if not hasattr(SetScrollFromPosX, 'func'):
    proc = rpr_getfp('ImGui_SetScrollFromPosX')
    SetScrollFromPosX.func = CFUNCTYPE(None, c_void_p, c_double, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(local_x), c_double(center_x_ratioInOptional) if center_x_ratioInOptional != None else None)
  SetScrollFromPosX.func(args[0], args[1], byref(args[2]) if args[2] != None else None)

def SetScrollFromPosY(ctx, local_y, center_y_ratioInOptional = None):
  if not hasattr(SetScrollFromPosY, 'func'):
    proc = rpr_getfp('ImGui_SetScrollFromPosY')
    SetScrollFromPosY.func = CFUNCTYPE(None, c_void_p, c_double, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(local_y), c_double(center_y_ratioInOptional) if center_y_ratioInOptional != None else None)
  SetScrollFromPosY.func(args[0], args[1], byref(args[2]) if args[2] != None else None)

def SetScrollHereX(ctx, center_x_ratioInOptional = None):
  if not hasattr(SetScrollHereX, 'func'):
    proc = rpr_getfp('ImGui_SetScrollHereX')
    SetScrollHereX.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(center_x_ratioInOptional) if center_x_ratioInOptional != None else None)
  SetScrollHereX.func(args[0], byref(args[1]) if args[1] != None else None)

def SetScrollHereY(ctx, center_y_ratioInOptional = None):
  if not hasattr(SetScrollHereY, 'func'):
    proc = rpr_getfp('ImGui_SetScrollHereY')
    SetScrollHereY.func = CFUNCTYPE(None, c_void_p, c_void_p)(proc)
  args = (c_void_p(ctx), c_double(center_y_ratioInOptional) if center_y_ratioInOptional != None else None)
  SetScrollHereY.func(args[0], byref(args[1]) if args[1] != None else None)

def SetScrollX(ctx, scroll_x):
  if not hasattr(SetScrollX, 'func'):
    proc = rpr_getfp('ImGui_SetScrollX')
    SetScrollX.func = CFUNCTYPE(None, c_void_p, c_double)(proc)
  args = (c_void_p(ctx), c_double(scroll_x))
  SetScrollX.func(args[0], args[1])

def SetScrollY(ctx, scroll_y):
  if not hasattr(SetScrollY, 'func'):
    proc = rpr_getfp('ImGui_SetScrollY')
    SetScrollY.func = CFUNCTYPE(None, c_void_p, c_double)(proc)
  args = (c_void_p(ctx), c_double(scroll_y))
  SetScrollY.func(args[0], args[1])
