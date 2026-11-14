#!/usr/bin/env python3
"""Generate a dependency-free Xcode project; safe to re-run after adding Swift files."""
from pathlib import Path
import hashlib
import plistlib
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--preview', action='store_true', help='Generate a separate Mac Catalyst preview project')
options = parser.parse_args()

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / ('cellscopePreview.xcodeproj' if options.preview else 'cellscope.xcodeproj')
PROJECT.mkdir(exist_ok=True)
def uid(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def q(value):
    return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"') + '"'
objects = []
def add(name, body):
    objects.append(f'{uid(name)} = {{ {body} }};')
    return uid(name)
sources = sorted([*ROOT.glob('cellscope/**/*.swift'), *ROOT.glob('Sources/**/*.swift')])
tests = sorted(ROOT.glob('cellscopeUITests/*.swift'))
app_builds, test_builds, refs = [], [], []
for file in sources + tests:
    relative = str(file.relative_to(ROOT))
    ref = add('ref:' + relative, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(relative)}; sourceTree = SOURCE_ROOT;')
    build = add('build:' + relative, f'isa = PBXBuildFile; fileRef = {ref};')
    refs.append(ref)
    (test_builds if file in tests else app_builds).append(build)
assets = add('assets', 'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = cellscope/Assets.xcassets; sourceTree = SOURCE_ROOT;')
assets_build = add('assets_build', f'isa = PBXBuildFile; fileRef = {assets};')
app_product = add('app_product', 'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = cellscope.app; sourceTree = BUILT_PRODUCTS_DIR;')
test_product = add('test_product', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = cellscopeUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
products = add('products', f'isa = PBXGroup; children = ({app_product}, {test_product}); name = Products; sourceTree = "<group>";')
main = add('main', f'isa = PBXGroup; children = ({", ".join(refs + [assets, products])}); sourceTree = "<group>";')
for name, builds in [('app_sources', app_builds), ('test_sources', test_builds)]:
    add(name, f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({", ".join(builds)}); runOnlyForDeploymentPostprocessing = 0;')
localized_builds = []
for filename in ['Localizable.strings', 'InfoPlist.strings']:
    children = []
    for language in ['en', 'zh-Hans']:
        child = add('locale:' + language + filename, f'isa = PBXFileReference; lastKnownFileType = text.plist.strings; name = {q(language)}; path = {q("cellscope/" + language + ".lproj/" + filename)}; sourceTree = SOURCE_ROOT;')
        children.append(child)
    variant = add('variant:' + filename, f'isa = PBXVariantGroup; children = ({", ".join(children)}); name = {q(filename)}; sourceTree = "<group>";')
    localized_builds.append(add('localized_build:' + filename, f'isa = PBXBuildFile; fileRef = {variant};'))
add('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({", ".join([assets_build] + localized_builds)}); runOnlyForDeploymentPostprocessing = 0;')
add('frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
proxy = add('proxy', f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {uid("app")}; remoteInfo = cellscope;')
dependency = add('dependency', f'isa = PBXTargetDependency; target = {uid("app")}; targetProxy = {proxy};')
for name in ['project', 'app', 'test']:
    configs = []
    for configuration in ['Debug', 'Release']:
        settings = {
            'SWIFT_VERSION': '5.0', 'IPHONEOS_DEPLOYMENT_TARGET': '17.0',
            'SDKROOT': 'iphoneos', 'CLANG_ENABLE_MODULES': 'YES',
            'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if configuration == 'Debug' else '-O',
            'DEBUG_INFORMATION_FORMAT': 'dwarf' if configuration == 'Debug' else 'dwarf-with-dsym',
            'SWIFT_ACTIVE_COMPILATION_CONDITIONS': 'DEBUG' if configuration == 'Debug' else '',
        }
        if name != 'project':
            settings.update({'PRODUCT_NAME': '$(TARGET_NAME)', 'CURRENT_PROJECT_VERSION': '5',
                'MARKETING_VERSION': '0.5.0', 'TARGETED_DEVICE_FAMILY': '1',
                'CODE_SIGN_STYLE': 'Automatic', 'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator',
                'SWIFT_EMIT_LOC_STRINGS': 'YES'})
        if name == 'app':
            settings.update({'PRODUCT_BUNDLE_IDENTIFIER': 'com.cellscope.counter',
                'INFOPLIST_FILE': 'cellscope/Info.plist', 'ASSETCATALOG_COMPILER_APPICON_NAME': 'AppIcon',
                'GENERATE_INFOPLIST_FILE': 'YES', 'INFOPLIST_KEY_UIApplicationSceneManifest_Generation': 'YES',
                'INFOPLIST_KEY_UILaunchScreen_Generation': 'YES', 'ENABLE_USER_SCRIPT_SANDBOXING': 'YES'})
        if name == 'test':
            settings.update({'PRODUCT_BUNDLE_IDENTIFIER': 'com.cellscope.counter.uitests',
                'GENERATE_INFOPLIST_FILE': 'YES', 'TEST_TARGET_NAME': 'cellscope'})
        if options.preview:
            settings.update({'SUPPORTS_MACCATALYST': 'YES', 'TARGETED_DEVICE_FAMILY': '1,2',
                'SUPPORTED_PLATFORMS': 'iphoneos iphonesimulator macosx'})
            if name == 'app':
                settings.update({'PRODUCT_BUNDLE_IDENTIFIER': 'com.cellscope.counter.preview',
                    'INFOPLIST_FILE': 'cellscope/Preview-Info.plist'})
        config = add(name + configuration, 'isa = XCBuildConfiguration; buildSettings = { ' + ' '.join(f'{key} = {q(value)};' for key, value in settings.items()) + f' }}; name = {configuration};')
        configs.append(config)
    add(name + '_configs', f'isa = XCConfigurationList; buildConfigurations = ({", ".join(configs)}); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
add('app', f'isa = PBXNativeTarget; buildConfigurationList = {uid("app_configs")}; buildPhases = ({uid("app_sources")}, {uid("frameworks")}, {uid("resources")}); buildRules = (); dependencies = (); name = cellscope; productName = cellscope; productReference = {app_product}; productType = "com.apple.product-type.application";')
add('test', f'isa = PBXNativeTarget; buildConfigurationList = {uid("test_configs")}; buildPhases = ({uid("test_sources")}); buildRules = (); dependencies = ({dependency}); name = cellscopeUITests; productName = cellscopeUITests; productReference = {test_product}; productType = "com.apple.product-type.bundle.ui-testing";')
add('project', f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = {{ {uid("test")} = {{ TestTargetID = {uid("app")}; }}; }}; }}; buildConfigurationList = {uid("project_configs")}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, "zh-Hans", Base); mainGroup = {main}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({uid("app")}, {uid("test")});')
(PROJECT / 'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(objects) + f'\n}}; rootObject = {uid("project")}; }}\n')
scheme = PROJECT / 'xcshareddata/xcschemes'
scheme.mkdir(parents=True, exist_ok=True)
def reference(target, product, name):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{uid(target)}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:{PROJECT.name}"/>'
app_ref = reference('app', 'cellscope.app', 'cellscope')
test_ref = reference('test', 'cellscopeUITests.xctest', 'cellscopeUITests')
(scheme / 'cellscope.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{app_ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{test_ref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{app_ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
info = {'CFBundleDisplayName': 'cellscope', 'CFBundleLocalizations': ['en', 'zh-Hans'], 'NSCameraUsageDescription': 'Capture microscope images for on-device cell counting.',
        'UISupportedInterfaceOrientations': ['UIInterfaceOrientationPortrait'], 'ITSAppUsesNonExemptEncryption': False}
if options.preview:
    info['CFBundleDisplayName'] = 'cellscope'
with (ROOT / ('cellscope/Preview-Info.plist' if options.preview else 'cellscope/Info.plist')).open('wb') as file:
    plistlib.dump(info, file)
print(f'Generated {PROJECT} with {len(sources)} app source files and {len(tests)} UI test files.')
