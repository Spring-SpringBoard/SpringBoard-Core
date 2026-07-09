Read rmlui-port-handoff-log.md, especially my messages (rather than work), to understand the current session. Read it all please.

I want you to continue working on this. Get the Lua + rmlui version functionality equivalent and ideally visually similar to the Lua + ChiliUI version.
Use the framework we created to automated visual testing, take screenshots and analyze them.
If you find rmlui errors/crashes, you _should_ go to the engine folder and fix them. Especially crashes. Do not work around that
engine folder: /home/gajop/projects/spring-projects/spring-bar
build command: ./docker-build-v2/build.sh linux

Fixing the immediate issues is not your priority, getting it _fully_ identical is, but here's the current state.

1. Buttons look quite similar already, but click + drag doesn't work.
2. Button click spawns an _additional_ textbox instead of hiding the button. It should show the text input, but the button should be hidden.
3. Combobox hasn't seen many improvements. When I click on it, it shows strings, very tightly packed together, but mouse hover on them doesn't act any differently (no indication of what element I'm hovering over)
4. Color picker works rather well, but I can only _click_ on the image, I cannot drag it - dragging feels critically important
5. dev console could use a fix too, since I cannot see errors anymore (proper text isn't being shown, probably commented out). It just shows "Text line 1", "Text line 2", "Text line 3" in 3 lines, probably some debug element. I'd like this fixed early on.
6. The top objects, map, env, misc tab header text feels like it's not properly centered
7. I get these errors when I open the units/features views
[t=00:05:02.406952][f=0008631] [SpringBoard] Opening editor: unitDefsView
[t=00:05:02.409857][f=0008631] [SpringBoard] Error: [string "scen_edit/view/view.lua"]:454: attempt to call method '_UpdateRmlUiGrid' (a nil value)
stack traceback:
        [string "scen_edit/util.lua"]:348: in function '_UpdateRmlUiGrid'
        [string "scen_edit/view/view.lua"]:454: in function '?'
        [string "scen_edit/util.lua"]:353: in function <[string "scen_edit/util.lua"]:352>
        [C]: in function 'xpcall'
        [string "scen_edit/util.lua"]:352: in function 'executeSafeDelayed'
        [string "scen_edit/util.lua"]:387: in function 'executeDelayed'
        [string "scen_edit/widget.lua"]:247: in function <[string "scen_edit/widget.lua"]:235>
        (tail call): ?
        [C]: in function 'pcall'
        [string "LuaHandler/Utilities/crashHandler.lua"]:50: in function 'f'
        [string "LuaHandler/Utilities/specialCallinHandlers.lua"]:78: in function <[string "LuaHandler/Utilities/specialCallinHandlers.lua"]:76>
[t=00:05:03.121906][f=0008652] [SpringBoard] Opening editor: featureDefsView
[t=00:05:03.125169][f=0008653] [SpringBoard] Error: [string "scen_edit/view/view.lua"]:454: attempt to call method '_UpdateRmlUiGrid' (a nil value)
stack traceback:
        [string "scen_edit/util.lua"]:348: in function '_UpdateRmlUiGrid'
        [string "scen_edit/view/view.lua"]:454: in function '?'
        [string "scen_edit/util.lua"]:353: in function <[string "scen_edit/util.lua"]:352>
        [C]: in function 'xpcall'
        [string "scen_edit/util.lua"]:352: in function 'executeSafeDelayed'
        [string "scen_edit/util.lua"]:387: in function 'executeDelayed'
        [string "scen_edit/widget.lua"]:247: in function <[string "scen_edit/widget.lua"]:235>
        (tail call): ?
        [C]: in function 'pcall'
        [string "LuaHandler/Utilities/crashHandler.lua"]:50: in function 'f'
        [string "LuaHandler/Utilities/specialCallinHandlers.lua"]:78: in function <[string "LuaHandler/Utilities/specialCallinHandlers.lua"]:76>
1. This error when I open Map Terrain/Texture/Metal/Grass
[t=00:05:57.571421][f=0010286] [SpringBoard] Opening editor: terrainSettings
[t=00:05:58.143713][f=0010303] [SpringBoard] Opening editor: grassEditor
[t=00:05:58.144612][f=0010303] Error: [RmlUi] [Lua] [string "scen_edit/view/rmlui_fields.lua"]:627: AssetView must have pathNav
[t=00:06:05.237273][f=0010516] [SpringBoard] Opening editor: textureEditor
[t=00:06:05.240885][f=0010516] Error: [RmlUi] [Lua] [string "scen_edit/view/rmlui_fields.lua"]:627: AssetView must have pathNav
[t=00:06:57.257371][f=0012076] [SpringBoard] Material Picker component initialized
1.  All of the Map ones (except settings) normally allow you to pick a brush, but that's not working.
2.  The checkboxes there feel a bit odd, they could use more spacing / better layout
3.  Texture picker doesn't work at all
4.  Material browser seems broken too with this error
[t=00:06:57.257371][f=0012076] [SpringBoard] Material Picker component initialized
[t=00:06:57.347211][f=0012076] Error: [RmlUi] [Lua] [string "scen_edit/view/rmlui_fields.lua"]:1268: MaterialBrowser must have pathNav
[t=00:06:57.734835][f=0012091] [SpringBoard] Material Picker component initialized
[t=00:06:57.826376][f=0012091] Error: [RmlUi] [Lua] [string "scen_edit/view/rmlui_fields.lua"]:1268: MaterialBrowser must have pathNav
1.  Clicking to Add teams causes an ASAN crash (requires an engine fix, still something you should do)
=================================================================
==198232==ERROR: AddressSanitizer: use-after-poison on address 0x720bf4f04820 at pc 0x5e1f270e4c8c bp 0x7fff71a4d4e0 sp 0x7fff71a4d4d0
WRITE of size 8 at 0x720bf4f04820 thread T0 (recoil-main)
    #0 0x5e1f270e4c8b in std::_Tuple_impl<0ul, Rml::Element*, Rml::Releaser<Rml::Element> >::_Tuple_impl(std::_Tuple_impl<0ul, Rml::Element*, Rml::Releaser<Rml::Element> >&&) /usr/include/c++/13/tuple:302
    #1 0x5e1f270e4c8b in std::tuple<Rml::Element*, Rml::Releaser<Rml::Element> >::tuple(std::tuple<Rml::Element*, Rml::Releaser<Rml::Element> >&&) /usr/include/c++/13/tuple:1351
    #2 0x5e1f270e4c8b in std::__uniq_ptr_impl<Rml::Element, Rml::Releaser<Rml::Element> >::__uniq_ptr_impl(std::__uniq_ptr_impl<Rml::Element, Rml::Releaser<Rml::Element> >&&) /usr/include/c++/13/bits/unique_ptr.h:185
    #3 0x5e1f270e4c8b in std::__uniq_ptr_data<Rml::Element, Rml::Releaser<Rml::Element>, true, true>::__uniq_ptr_data(std::__uniq_ptr_data<Rml::Element, Rml::Releaser<Rml::Element>, true, true>&&) /usr/include/c++/13/bits/unique_ptr.h:242
    #4 0x5e1f270e4c8b in std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> >::unique_ptr(std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> >&&) /usr/include/c++/13/bits/unique_ptr.h:366
    #5 0x5e1f270e4c8b in decltype (::new ((void*)(0)) std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> >((declval<std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> > >)())) std::construct_at<std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> >, std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> > >(std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> >*, std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> >&&) /usr/include/c++/13/bits/stl_construct.h:97
    #6 0x5e1f270e4c8b in void std::allocator_traits<std::allocator<std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> > > >::construct<std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> >, std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> > >(std::allocator<std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> > >&, std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> >*, std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> >&&) /usr/include/c++/13/bits/alloc_traits.h:539
    #7 0x5e1f270e4c8b in std::vector<std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> >, std::allocator<std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> > > >::_M_insert_rval(__gnu_cxx::__normal_iterator<std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> > const*, std::vector<std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> >, std::allocator<std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> > > > >, std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> >&&) /usr/include/c++/13/bits/vector.tcc:364
    #8 0x5e1f270e4c8b in std::vector<std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> >, std::allocator<std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> > > >::insert(__gnu_cxx::__normal_iterator<std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> > const*, std::vector<std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> >, std::allocator<std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> > > > >, std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> >&&) /usr/include/c++/13/bits/stl_vector.h:1391
    #9 0x5e1f270e4c8b in Rml::Element::AppendChild(std::unique_ptr<Rml::Element, Rml::Releaser<Rml::Element> >, bool) /build/src/rts/lib/RmlUi/Source/Core/Element.cpp:1306
    #10 0x5e1f273d7e08 in Rml::XMLNodeHandlerDefault::ElementStart(Rml::XMLParser*, std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&, itlib::flat_map<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >, Rml::Variant, itlib::fmimpl::less, std::vector<std::pair<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >, Rml::Variant>, std::allocator<std::pair<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >, Rml::Variant> > > > const&) /build/src/rts/lib/RmlUi/Source/Core/XMLNodeHandlerDefault.cpp:32
    #11 0x5e1f273e62b5 in Rml::XMLParser::HandleElementStart(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&, itlib::flat_map<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >, Rml::Variant, itlib::fmimpl::less, std::vector<std::pair<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >, Rml::Variant>, std::allocator<std::pair<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >, Rml::Variant> > > > const&) /build/src/rts/lib/RmlUi/Source/Core/XMLParser.cpp:151
    #12 0x5e1f274ea762 in Rml::BaseXMLParser::HandleElementStartInternal(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&, itlib::flat_map<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >, Rml::Variant, itlib::fmimpl::less, std::vector<std::pair<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >, Rml::Variant>, std::allocator<std::pair<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >, Rml::Variant> > > > const&) /build/src/rts/lib/RmlUi/Source/Core/BaseXMLParser.cpp:100
    #13 0x5e1f274ea762 in Rml::BaseXMLParser::HandleElementStartInternal(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&, itlib::flat_map<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >, Rml::Variant, itlib::fmimpl::less, std::vector<std::pair<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >, Rml::Variant>, std::allocator<std::pair<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >, Rml::Variant> > > > const&) /build/src/rts/lib/RmlUi/Source/Core/BaseXMLParser.cpp:96
    #14 0x5e1f274ea762 in Rml::BaseXMLParser::ReadOpenTag() /build/src/rts/lib/RmlUi/Source/Core/BaseXMLParser.cpp:220
    #15 0x5e1f274eb297 in Rml::BaseXMLParser::ReadBody() /build/src/rts/lib/RmlUi/Source/Core/BaseXMLParser.cpp:165
    #16 0x5e1f274eb6dc in Rml::BaseXMLParser::Parse(Rml::Stream*) /build/src/rts/lib/RmlUi/Source/Core/BaseXMLParser.cpp:53
    #17 0x5e1f271c56a2 in Rml::Factory::InstanceElementStream(Rml::Element*, Rml::Stream*) /build/src/rts/lib/RmlUi/Source/Core/Factory.cpp:425
    #18 0x5e1f271c56a2 in Rml::Factory::InstanceElementText(Rml::Element*, std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&) /build/src/rts/lib/RmlUi/Source/Core/Factory.cpp:381
    #19 0x5e1f270e3f05 in Rml::Element::SetInnerRML(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&) /build/src/rts/lib/RmlUi/Source/Core/Element.cpp:1135
    #20 0x5e1f2526223a in void sol::member_function_wrapper<void (Rml::Element::*)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), void, Rml::Element, std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&>::call<void (Rml::Element::*&)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > >(void (Rml::Element::*&)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), Rml::Element&, std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >&&) /build/src/rts/lib/sol2/sol.hpp:17338
    #21 0x5e1f2526223a in decltype(auto) sol::member_function_wrapper<void (Rml::Element::*)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), void, Rml::Element, std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&>::caller::operator()<void (Rml::Element::*&)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > >(void (Rml::Element::*&)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), Rml::Element&, std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >&&) const /build/src/rts/lib/sol2/sol.hpp:17344
    #22 0x5e1f2526223a in eval<true, sol::argument_handler<sol::types<void, const std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >&> >&, sol::member_function_wrapper<void (Rml::Element::*)(const std::__cxx11::basic_string<char>&), void, Rml::Element, const std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >&>::caller, void (Rml::Element::*&)(const std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >&), Rml::Element&, std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > > /build/src/rts/lib/sol2/sol.hpp:16078
    #23 0x5e1f2526223a in eval<true, const std::__cxx11::basic_string<char>&, 0, sol::argument_handler<sol::types<void, const std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >&> >&, sol::member_function_wrapper<void (Rml::Element::*)(const std::__cxx11::basic_string<char>&), void, Rml::Element, const std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >&>::caller, void (Rml::Element::*&)(const std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >&), Rml::Element&> /build/src/rts/lib/sol2/sol.hpp:16101
    #24 0x5e1f2539324b in decltype(auto) sol::stack::stack_detail::call<true, 0ul, void, std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&, sol::member_function_wrapper<void (Rml::Element::*)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), void, Rml::Element, std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&>::caller, void (Rml::Element::*&)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), Rml::Element&>(sol::types<void>, sol::types<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&>, std::integer_sequence<unsigned long, 0ul>, lua_State*, int, sol::member_function_wrapper<void (Rml::Element::*)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), void, Rml::Element, std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&>::caller&&, void (Rml::Element::*&)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), Rml::Element&) /build/src/rts/lib/sol2/sol.hpp:16127
    #25 0x5e1f2539324b in decltype(auto) sol::stack::call<true, void, std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&, sol::member_function_wrapper<void (Rml::Element::*)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), void, Rml::Element, std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&>::caller, void (Rml::Element::*&)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), Rml::Element&>(sol::types<void>, sol::types<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&>, lua_State*, int, sol::member_function_wrapper<void (Rml::Element::*)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), void, Rml::Element, std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&>::caller&&, void (Rml::Element::*&)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), Rml::Element&) /build/src/rts/lib/sol2/sol.hpp:16147
    #26 0x5e1f2539324b in int sol::stack::call_into_lua<true, true, void, , std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&, sol::member_function_wrapper<void (Rml::Element::*)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), void, Rml::Element, std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&>::caller, void (Rml::Element::*&)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), Rml::Element&>(sol::types<void>, sol::types<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&>, lua_State*, int, sol::member_function_wrapper<void (Rml::Element::*)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), void, Rml::Element, std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&>::caller&&, void (Rml::Element::*&)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), Rml::Element&) /build/src/rts/lib/sol2/sol.hpp:16189
    #27 0x5e1f2539324b in int sol::call_detail::lua_call_wrapper<Rml::Element, void (Rml::Element::*)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), false, true, true, 0, true, void>::call<void (Rml::Element::*&)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), Rml::Element&>(lua_State*, void (Rml::Element::*&)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), Rml::Element&) /build/src/rts/lib/sol2/sol.hpp:18103
    #28 0x5e1f2539324b in int sol::call_detail::lua_call_wrapper<Rml::Element, void (Rml::Element::*)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&), false, true, true, 0, true, void>::call<void (Rml::Element::*&)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&)>(lua_State*, void (Rml::Element::*&)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&)) /build/src/rts/lib/sol2/sol.hpp:18093
    #29 0x5e1f2539324b in int sol::call_detail::lua_call_wrapper<Rml::Element, sol::property_wrapper<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const& (Rml::Element::*)() const, void (Rml::Element::*)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&)>, false, true, true, 0, true, void>::call<sol::property_wrapper<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const& (Rml::Element::*)() const, void (Rml::Element::*)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&)>&>(lua_State*, sol::property_wrapper<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const& (Rml::Element::*)() const, void (Rml::Element::*)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&)>&) /build/src/rts/lib/sol2/sol.hpp:18387
    #30 0x5e1f2539324b in int sol::call_detail::call_wrapped<Rml::Element, false, true, 0, true, true, sol::property_wrapper<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const& (Rml::Element::*)() const, void (Rml::Element::*)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&)>&>(lua_State*, sol::property_wrapper<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const& (Rml::Element::*)() const, void (Rml::Element::*)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&)>&) /build/src/rts/lib/sol2/sol.hpp:18506
    #31 0x5e1f2539324b in int sol::u_detail::binding<char [3], sol::property_wrapper<std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const& (Rml::Element::*)() const, void (Rml::Element::*)(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&)>, Rml::Element>::index_call_with_<false, true>(lua_State*, void*) /build/src/rts/lib/sol2/sol.hpp:23063
    #32 0x5e1f2528fc0a in int sol::u_detail::usertype_storage_base::self_index_call<true, false, false>(sol::types<>, lua_State*, sol::u_detail::usertype_storage_base&) /build/src/rts/lib/sol2/sol.hpp:23423
    #33 0x5e1f2534907c in int sol::u_detail::usertype_storage<Rml::Element>::index_call_<true, false>(lua_State*) /build/src/rts/lib/sol2/sol.hpp:23560
    #34 0x5e1f2436d9ba in sol::detail::lua_cfunction_trampoline(lua_State*, int (*)(lua_State*)) /build/src/rts/lib/sol2/sol.hpp:8398
    #35 0x5e1f252db6cf in int sol::detail::static_trampoline<&(int sol::u_detail::usertype_storage<Rml::Element>::index_call_<true, false>(lua_State*))>(lua_State*) /build/src/rts/lib/sol2/sol.hpp:8423
    #36 0x5e1f252db6cf in int sol::u_detail::usertype_storage<Rml::Element>::index_call<true>(lua_State*) /build/src/rts/lib/sol2/sol.hpp:23572
    #37 0x5e1f25f0863f in luaD_precall(lua_State*, lua_TValue*, int) /build/src/rts/lib/lua/src/ldo.cpp:320
    #38 0x5e1f25f094b0 in luaD_call(lua_State*, lua_TValue*, int) /build/src/rts/lib/lua/src/ldo.cpp:377
    #39 0x5e1f25f34a4f in callTM /build/src/rts/lib/lua/src/lvm.cpp:127
    #40 0x5e1f25f34a4f in luaV_settable(lua_State*, lua_TValue const*, lua_TValue*, lua_TValue*) /build/src/rts/lib/lua/src/lvm.cpp:177
    #41 0x5e1f25f37d5b in luaV_execute(lua_State*, int) /build/src/rts/lib/lua/src/lvm.cpp:487
    #42 0x5e1f25f09544 in luaD_call(lua_State*, lua_TValue*, int) /build/src/rts/lib/lua/src/ldo.cpp:378
    #43 0x5e1f25ef2778 in f_call /build/src/rts/lib/lua/src/lapi.cpp:812
    #44 0x5e1f25f06c78 in luaD_rawrunprotected(lua_State*, void (*)(lua_State*, void*), void*) /build/src/rts/lib/lua/src/ldo.cpp:116
    #45 0x5e1f25f09e82 in luaD_pcall(lua_State*, void (*)(lua_State*, void*), void*, long, long) /build/src/rts/lib/lua/src/ldo.cpp:464
    #46 0x5e1f25efa755 in lua_pcall(lua_State*, int, int, int) /build/src/rts/lib/lua/src/lapi.cpp:833
    #47 0x5e1f25eff863 in luaB_xpcall /build/src/rts/lib/lua/src/lbaselib.cpp:401
    #48 0x5e1f25f0863f in luaD_precall(lua_State*, lua_TValue*, int) /build/src/rts/lib/lua/src/ldo.cpp:320
    #49 0x5e1f25f36a42 in luaV_execute(lua_State*, int) /build/src/rts/lib/lua/src/lvm.cpp:620
    #50 0x5e1f25f09544 in luaD_call(lua_State*, lua_TValue*, int) /build/src/rts/lib/lua/src/ldo.cpp:378
    #51 0x5e1f25ef2778 in f_call /build/src/rts/lib/lua/src/lapi.cpp:812
    #52 0x5e1f25f06c78 in luaD_rawrunprotected(lua_State*, void (*)(lua_State*, void*), void*) /build/src/rts/lib/lua/src/ldo.cpp:116
    #53 0x5e1f25f09e82 in luaD_pcall(lua_State*, void (*)(lua_State*, void*), void*, long, long) /build/src/rts/lib/lua/src/ldo.cpp:464
    #54 0x5e1f25efa755 in lua_pcall(lua_State*, int, int, int) /build/src/rts/lib/lua/src/lapi.cpp:833
    #55 0x5e1f25eff863 in luaB_xpcall /build/src/rts/lib/lua/src/lbaselib.cpp:401
    #56 0x5e1f25f0863f in luaD_precall(lua_State*, lua_TValue*, int) /build/src/rts/lib/lua/src/ldo.cpp:320
    #57 0x5e1f25f36a42 in luaV_execute(lua_State*, int) /build/src/rts/lib/lua/src/lvm.cpp:620
    #58 0x5e1f25f09544 in luaD_call(lua_State*, lua_TValue*, int) /build/src/rts/lib/lua/src/ldo.cpp:378
    #59 0x5e1f25ef2778 in f_call /build/src/rts/lib/lua/src/lapi.cpp:812
    #60 0x5e1f25f06c78 in luaD_rawrunprotected(lua_State*, void (*)(lua_State*, void*), void*) /build/src/rts/lib/lua/src/ldo.cpp:116
    #61 0x5e1f25f09e82 in luaD_pcall(lua_State*, void (*)(lua_State*, void*), void*, long, long) /build/src/rts/lib/lua/src/ldo.cpp:464
    #62 0x5e1f25efa755 in lua_pcall(lua_State*, int, int, int) /build/src/rts/lib/lua/src/lapi.cpp:833
    #63 0x5e1f23f9e485 in ScopedLuaCall /build/src/rts/Lua/LuaHandle.cpp:397
    #64 0x5e1f23f9e485 in CLuaHandle::RunCallInTraceback(lua_State*, LuaHashString const*, std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >*, int, int, int, bool) /build/src/rts/Lua/LuaHandle.cpp:483
    #65 0x5e1f23f9fc18 in CLuaHandle::RunCallInTraceback(lua_State*, LuaHashString const&, int, int, int, bool) /build/src/rts/Lua/LuaHandle.cpp:494
    #66 0x5e1f23fa026a in CLuaHandle::RunCallIn(lua_State*, LuaHashString const&, int, int) /build/src/rts/Lua/LuaHandle.h:429
    #67 0x5e1f23fa026a in CLuaHandle::XCall(lua_State*, char const*) /build/src/rts/Lua/LuaHandle.cpp:326
    #68 0x5e1f24007d43 in HandleXCall /build/src/rts/Lua/LuaInterCall.cpp:69
    #69 0x5e1f25f0863f in luaD_precall(lua_State*, lua_TValue*, int) /build/src/rts/lib/lua/src/ldo.cpp:320
    #70 0x5e1f25f36a42 in luaV_execute(lua_State*, int) /build/src/rts/lib/lua/src/lvm.cpp:620
    #71 0x5e1f25f09544 in luaD_call(lua_State*, lua_TValue*, int) /build/src/rts/lib/lua/src/ldo.cpp:378
    #72 0x5e1f25ef2778 in f_call /build/src/rts/lib/lua/src/lapi.cpp:812
    #73 0x5e1f25f06c78 in luaD_rawrunprotected(lua_State*, void (*)(lua_State*, void*), void*) /build/src/rts/lib/lua/src/ldo.cpp:116
    #74 0x5e1f25f09e82 in luaD_pcall(lua_State*, void (*)(lua_State*, void*), void*, long, long) /build/src/rts/lib/lua/src/ldo.cpp:464
    #75 0x5e1f25efa755 in lua_pcall(lua_State*, int, int, int) /build/src/rts/lib/lua/src/lapi.cpp:833
    #76 0x5e1f23f9e485 in ScopedLuaCall /build/src/rts/Lua/LuaHandle.cpp:397
    #77 0x5e1f23f9e485 in CLuaHandle::RunCallInTraceback(lua_State*, LuaHashString const*, std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >*, int, int, int, bool) /build/src/rts/Lua/LuaHandle.cpp:483
    #78 0x5e1f23f9fc18 in CLuaHandle::RunCallInTraceback(lua_State*, LuaHashString const&, int, int, int, bool) /build/src/rts/Lua/LuaHandle.cpp:494
    #79 0x5e1f23fef76a in CLuaHandle::RunCallIn(lua_State*, LuaHashString const&, int, int) /build/src/rts/Lua/LuaHandle.h:429
    #80 0x5e1f23fef76a in CUnsyncedLuaHandle::RecvFromSynced(lua_State*, int) /build/src/rts/Lua/LuaHandleSynced.cpp:195
    #81 0x5e1f23fef983 in CSyncedLuaHandle::SendToUnsynced(lua_State*) /build/src/rts/Lua/LuaHandleSynced.cpp:2013
    #82 0x5e1f25f0863f in luaD_precall(lua_State*, lua_TValue*, int) /build/src/rts/lib/lua/src/ldo.cpp:320
    #83 0x5e1f25f36a42 in luaV_execute(lua_State*, int) /build/src/rts/lib/lua/src/lvm.cpp:620
    #84 0x5e1f25f09544 in luaD_call(lua_State*, lua_TValue*, int) /build/src/rts/lib/lua/src/ldo.cpp:378
    #85 0x5e1f25ef2778 in f_call /build/src/rts/lib/lua/src/lapi.cpp:812
    #86 0x5e1f25f06c78 in luaD_rawrunprotected(lua_State*, void (*)(lua_State*, void*), void*) /build/src/rts/lib/lua/src/ldo.cpp:116
    #87 0x5e1f25f09e82 in luaD_pcall(lua_State*, void (*)(lua_State*, void*), void*, long, long) /build/src/rts/lib/lua/src/ldo.cpp:464
    #88 0x5e1f25efa755 in lua_pcall(lua_State*, int, int, int) /build/src/rts/lib/lua/src/lapi.cpp:833
    #89 0x5e1f25eff863 in luaB_xpcall /build/src/rts/lib/lua/src/lbaselib.cpp:401
    #90 0x5e1f25f0863f in luaD_precall(lua_State*, lua_TValue*, int) /build/src/rts/lib/lua/src/ldo.cpp:320
    #91 0x5e1f25f36a42 in luaV_execute(lua_State*, int) /build/src/rts/lib/lua/src/lvm.cpp:620
    #92 0x5e1f25f09544 in luaD_call(lua_State*, lua_TValue*, int) /build/src/rts/lib/lua/src/ldo.cpp:378
    #93 0x5e1f25ef2778 in f_call /build/src/rts/lib/lua/src/lapi.cpp:812
    #94 0x5e1f25f06c78 in luaD_rawrunprotected(lua_State*, void (*)(lua_State*, void*), void*) /build/src/rts/lib/lua/src/ldo.cpp:116
    #95 0x5e1f25f09e82 in luaD_pcall(lua_State*, void (*)(lua_State*, void*), void*, long, long) /build/src/rts/lib/lua/src/ldo.cpp:464
    #96 0x5e1f25efa755 in lua_pcall(lua_State*, int, int, int) /build/src/rts/lib/lua/src/lapi.cpp:833
    #97 0x5e1f23f9e485 in ScopedLuaCall /build/src/rts/Lua/LuaHandle.cpp:397
    #98 0x5e1f23f9e485 in CLuaHandle::RunCallInTraceback(lua_State*, LuaHashString const*, std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> >*, int, int, int, bool) /build/src/rts/Lua/LuaHandle.cpp:483
    #99 0x5e1f23f9fc18 in CLuaHandle::RunCallInTraceback(lua_State*, LuaHashString const&, int, int, int, bool) /build/src/rts/Lua/LuaHandle.cpp:494
    #100 0x5e1f23fa5b38 in CLuaHandle::RunCallIn(lua_State*, LuaHashString const&, int, int) /build/src/rts/Lua/LuaHandle.h:429
    #101 0x5e1f23fa5b38 in CLuaHandle::RecvLuaMsg(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&, int) /build/src/rts/Lua/LuaHandle.cpp:2356
    #102 0x5e1f23fa5ff9 in CSplitLuaHandle::RecvLuaMsg(std::__cxx11::basic_string<char, std::char_traits<char>, std::allocator<char> > const&, int) /build/src/rts/Lua/LuaHandleSynced.h:188
    #103 0x5e1f23fa5ff9 in CLuaHandle::HandleLuaMsg(int, int, int, std::vector<unsigned char, std::allocator<unsigned char> > const&) /build/src/rts/Lua/LuaHandle.cpp:2466
    #104 0x5e1f23efe1af in CGame::ClientReadNet() /build/src/rts/Net/NetCommands.cpp:1031
    #105 0x5e1f27833876 in CGame::Update() /build/src/rts/Game/Game.cpp:1178
    #106 0x5e1f2586e708 in SpringApp::Update() /build/src/rts/System/SpringApp.cpp:889
    #107 0x5e1f2587bdcb in SpringApp::Run() /build/src/rts/System/SpringApp.cpp:930
    #108 0x5e1f257e9719 in Run(int, char**) /build/src/rts/System/Main.cpp:51
    #109 0x5e1f23d5c0f3 in main /build/src/rts/System/Main.cpp:104
    #110 0x720bf662a1c9 in __libc_start_call_main ../sysdeps/nptl/libc_start_call_main.h:58
    #111 0x720bf662a28a in __libc_start_main_impl ../csu/libc-start.c:360
    #112 0x5e1f23e18819 in _start (/home/gajop/projects/spring-projects/spring-bar/build-amd64-linux/install/spring+0x9fb819)

Address 0x720bf4f04820 is a wild pointer inside of access range of size 0x000000000008.
SUMMARY: AddressSanitizer: use-after-poison /usr/include/c++/13/tuple:302 in std::_Tuple_impl<0ul, Rml::Element*, Rml::Releaser<Rml::Element> >::_Tuple_impl(std::_Tuple_impl<0ul, Rml::Element*, Rml::Releaser<Rml::Element> >&&)
Shadow bytes around the buggy address:
  0x720bf4f04580: f7 f7 00 00 00 00 00 00 00 00 00 00 00 00 00 00
  0x720bf4f04600: 00 00 00 00 00 00 00 00 f7 f7 00 00 f7 f7 00 00
  0x720bf4f04680: f7 f7 f7 f7 00 00 00 00 00 00 00 00 00 00 f7 f7
  0x720bf4f04700: f7 f7 00 00 00 00 00 00 00 00 00 00 f7 f7 f7 f7
  0x720bf4f04780: 00 00 f7 f7 00 00 00 00 f7 f7 00 00 00 00 00 00
=>0x720bf4f04800: f7 f7 00 00[f7]f7 00 00 f7 f7 00 00 f7 f7 00 00
  0x720bf4f04880: 00 00 00 00 f7 f7 f7 f7 00 00 00 00 00 00 00 00
  0x720bf4f04900: f7 f7 f7 f7 00 00 f7 f7 00 00 00 00 f7 f7 f7 f7
  0x720bf4f04980: 00 00 f7 f7 f7 f7 00 00 f7 f7 f7 f7 f7 f7 00 00
  0x720bf4f04a00: f7 f7 00 00 f7 f7 00 00 00 00 00 00 f7 f7 00 00
  0x720bf4f04a80: 00 00 f7 f7 f7 f7 f7 f7 f7 f7 00 00 00 00 f7 f7
Shadow byte legend (one shadow byte represents 8 application bytes):
  Addressable:           00
  Partially addressable: 01 02 03 04 05 06 07
  Heap left redzone:       fa
  Freed heap region:       fd
  Stack left redzone:      f1
  Stack mid redzone:       f2
  Stack right redzone:     f3
  Stack after return:      f5
  Stack use after scope:   f8
  Global redzone:          f9
  Global init order:       f6
  Poisoned by user:        f7
  Container overflow:      fc
  Array cookie:            ac
  Intra object redzone:    bb
  ASan internal:           fe
  Left alloca redzone:     ca
  Right alloca redzone:    cb
==198232==ABORTING
error: Recipe `run` failed on line 93 with exit code 1