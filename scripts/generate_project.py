#!/usr/bin/env python3
"""Generate the checked-in Xcode project using Python's standard library.

Run this after adding or removing Swift files. Existing Swift files and resources
are never changed. IDs and output order are deterministic for reviewable diffs.
"""

from __future__ import annotations

import hashlib
from pathlib import Path
import re
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "Plurifold.xcodeproj"
OBJECTS: dict[str, dict] = {}


def identifier(label: str) -> str:
    return hashlib.sha256(label.encode("utf-8")).hexdigest()[:24].upper()


def add(label: str, isa: str, **attributes) -> str:
    key = identifier(label)
    if key in OBJECTS:
        raise ValueError(f"Duplicate project object: {label}")
    OBJECTS[key] = {"isa": isa, **attributes}
    return key


def serialize(value, indent: int = 0) -> str:
    pad = "\t" * indent
    if isinstance(value, dict):
        if not value:
            return "{}"
        lines = ["{"]
        for key, child in value.items():
            lines.append(f"{pad}\t{serialize(key)} = {serialize(child, indent + 1)};")
        lines.append(pad + "}")
        return "\n".join(lines)
    if isinstance(value, list):
        if not value:
            return "()"
        return "(\n" + "\n".join(
            f"{pad}\t{serialize(child, indent + 1)}," for child in value
        ) + f"\n{pad})"
    if isinstance(value, int):
        return str(value)
    value = str(value)
    if re.fullmatch(r"[A-Za-z0-9_./]+", value):
        return value
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def add_file(path: Path, file_type: str) -> str:
    name = relative(path)
    return add("file:" + name, "PBXFileReference", lastKnownFileType=file_type,
               name=path.name, path=name, sourceTree="SOURCE_ROOT")


def add_build_file(path: Path, file_ref: str) -> str:
    return add("build:" + relative(path), "PBXBuildFile", fileRef=file_ref)


def add_phase(label: str, kind: str, files: list[str]) -> str:
    return add(label, kind, buildActionMask=2147483647, files=files,
               runOnlyForDeploymentPostprocessing=0)


def configurations(label: str, shared: dict, debug: dict, release: dict) -> str:
    configurations = []
    for name, specific in [("Debug", debug), ("Release", release)]:
        configurations.append(add(f"config:{label}:{name}", "XCBuildConfiguration",
                                  buildSettings={**shared, **specific}, name=name))
    return add("configs:" + label, "XCConfigurationList",
               buildConfigurations=configurations, defaultConfigurationIsVisible=0,
               defaultConfigurationName="Release")


def validate_graph() -> None:
    """Catch missing PBX references and absent source/resource files before writing."""
    def check(value) -> None:
        if isinstance(value, dict):
            for key, child in value.items():
                check(key)
                check(child)
        elif isinstance(value, list):
            for child in value:
                check(child)
        elif isinstance(value, str) and re.fullmatch(r"[0-9A-F]{24}", value):
            if value not in OBJECTS:
                raise ValueError(f"Dangling project reference: {value}")

    for item in OBJECTS.values():
        check(item)
        if item["isa"] == "PBXFileReference" and item["sourceTree"] == "SOURCE_ROOT":
            path = ROOT / item["path"]
            is_asset_catalog = item.get("lastKnownFileType") == "folder.assetcatalog"
            if not (path.is_dir() if is_asset_catalog else path.is_file()):
                raise FileNotFoundError(item["path"])
        if item["isa"].endswith("BuildPhase"):
            members = item.get("files", [])
            if len(members) != len(set(members)):
                raise ValueError("Duplicate build-phase membership")


def write_scheme(app_target: str, test_target: str) -> None:
    def reference(parent, target: str, name: str, product: str) -> None:
        ET.SubElement(parent, "BuildableReference", BuildableIdentifier="primary",
                      BlueprintIdentifier=target, BuildableName=product,
                      BlueprintName=name, ReferencedContainer="container:Plurifold.xcodeproj")

    scheme = ET.Element("Scheme", LastUpgradeVersion="1500", version="1.3")
    build = ET.SubElement(scheme, "BuildAction", parallelizeBuildables="YES",
                          buildImplicitDependencies="YES")
    entries = ET.SubElement(build, "BuildActionEntries")
    app_entry = ET.SubElement(entries, "BuildActionEntry", buildForTesting="YES",
                              buildForRunning="YES", buildForProfiling="YES",
                              buildForArchiving="YES", buildForAnalyzing="YES")
    reference(app_entry, app_target, "Plurifold", "Plurifold.app")
    test_entry = ET.SubElement(entries, "BuildActionEntry", buildForTesting="YES",
                               buildForRunning="NO", buildForProfiling="NO",
                               buildForArchiving="NO", buildForAnalyzing="YES")
    reference(test_entry, test_target, "PlurifoldTests", "PlurifoldTests.xctest")
    test = ET.SubElement(scheme, "TestAction", buildConfiguration="Debug",
                         selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB",
                         selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB",
                         shouldUseLaunchSchemeArgsEnv="YES")
    macro = ET.SubElement(test, "MacroExpansion")
    reference(macro, app_target, "Plurifold", "Plurifold.app")
    testables = ET.SubElement(test, "Testables")
    testable = ET.SubElement(testables, "TestableReference", skipped="NO")
    reference(testable, test_target, "PlurifoldTests", "PlurifoldTests.xctest")
    launch = ET.SubElement(scheme, "LaunchAction", buildConfiguration="Debug",
                           selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB",
                           selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB",
                           launchStyle="0", useCustomWorkingDirectory="NO",
                           ignoresPersistentStateOnLaunch="NO", debugDocumentVersioning="YES",
                           debugServiceExtension="internal", allowLocationSimulation="YES")
    runnable = ET.SubElement(launch, "BuildableProductRunnable", runnableDebuggingMode="0")
    reference(runnable, app_target, "Plurifold", "Plurifold.app")
    profile = ET.SubElement(scheme, "ProfileAction", buildConfiguration="Release",
                            shouldUseLaunchSchemeArgsEnv="YES", savedToolIdentifier="",
                            useCustomWorkingDirectory="NO", debugDocumentVersioning="YES")
    runnable = ET.SubElement(profile, "BuildableProductRunnable", runnableDebuggingMode="0")
    reference(runnable, app_target, "Plurifold", "Plurifold.app")
    ET.SubElement(scheme, "AnalyzeAction", buildConfiguration="Debug")
    ET.SubElement(scheme, "ArchiveAction", buildConfiguration="Release",
                  revealArchiveInOrganizer="YES")
    ET.indent(scheme, space="   ")
    destination = PROJECT / "xcshareddata" / "xcschemes" / "Plurifold.xcscheme"
    destination.parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(scheme).write(destination, encoding="UTF-8", xml_declaration=True)


def main() -> None:
    app_sources = sorted((ROOT / "Plurifold").rglob("*.swift"))
    test_sources = sorted((ROOT / "PlurifoldTests").rglob("*.swift"))
    resources = sorted(path for path in (ROOT / "Plurifold").rglob("*")
                       if (path.is_file() and path.name in {"catalog.json", "PrivacyInfo.xcprivacy"})
                       or (path.is_dir() and path.suffix == ".xcassets"))
    if not app_sources:
        raise SystemExit("No app Swift files found under Plurifold/.")
    if len([path for path in resources if path.name == "catalog.json"]) != 1:
        raise SystemExit("Exactly one catalog.json must be included in the app bundle.")
    if len([path for path in resources if path.name == "PrivacyInfo.xcprivacy"]) != 1:
        raise SystemExit("Exactly one app PrivacyInfo.xcprivacy is required.")
    if not (ROOT / "Plurifold/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json").is_file():
        raise SystemExit("The AppIcon asset catalog is required. Run scripts/generate_app_icon.py.")

    app_refs, app_builds, test_refs, test_builds, resource_builds = [], [], [], [], []
    for path in app_sources:
        file_ref = add_file(path, "sourcecode.swift")
        app_refs.append(file_ref)
        app_builds.append(add_build_file(path, file_ref))
    for path in resources:
        resource_type = {
            ".json": "text.json", ".xcprivacy": "text.xml", ".xcassets": "folder.assetcatalog"
        }[path.suffix]
        file_ref = add_file(path, resource_type)
        app_refs.append(file_ref)
        resource_builds.append(add_build_file(path, file_ref))
    for path in test_sources:
        file_ref = add_file(path, "sourcecode.swift")
        test_refs.append(file_ref)
        test_builds.append(add_build_file(path, file_ref))

    app_product = add("product:app", "PBXFileReference", explicitFileType="wrapper.application",
                      includeInIndex=0, path="Plurifold.app", sourceTree="BUILT_PRODUCTS_DIR")
    test_product = add("product:tests", "PBXFileReference", explicitFileType="wrapper.cfbundle",
                       includeInIndex=0, path="PlurifoldTests.xctest", sourceTree="BUILT_PRODUCTS_DIR")
    app_group = add("group:app", "PBXGroup", children=app_refs, name="Plurifold", sourceTree="<group>")
    test_group = add("group:tests", "PBXGroup", children=test_refs, name="PlurifoldTests", sourceTree="<group>")
    products = add("group:products", "PBXGroup", children=[app_product, test_product],
                   name="Products", sourceTree="<group>")
    root_group = add("group:root", "PBXGroup", children=[app_group, test_group, products], sourceTree="<group>")

    app_phases = [add_phase("phase:app:sources", "PBXSourcesBuildPhase", app_builds),
                  add_phase("phase:app:frameworks", "PBXFrameworksBuildPhase", []),
                  add_phase("phase:app:resources", "PBXResourcesBuildPhase", resource_builds)]
    test_phases = [add_phase("phase:tests:sources", "PBXSourcesBuildPhase", test_builds),
                   add_phase("phase:tests:frameworks", "PBXFrameworksBuildPhase", []),
                   add_phase("phase:tests:resources", "PBXResourcesBuildPhase", [])]

    project_configs = configurations("project", {
        "ALWAYS_SEARCH_USER_PATHS": "NO", "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES", "COPY_PHASE_STRIP": "NO",
        "GCC_C_LANGUAGE_STANDARD": "gnu17", "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "SDKROOT": "iphoneos", "SWIFT_VERSION": "5.0",
    }, {
        "DEBUG_INFORMATION_FORMAT": "dwarf", "ENABLE_TESTABILITY": "YES",
        "GCC_OPTIMIZATION_LEVEL": "0", "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
        "ONLY_ACTIVE_ARCH": "YES", "SWIFT_ACTIVE_COMPILATION_CONDITIONS": ["DEBUG", "$(inherited)"],
        "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
    }, {
        "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym", "SWIFT_COMPILATION_MODE": "wholemodule",
        "SWIFT_OPTIMIZATION_LEVEL": "-O", "VALIDATE_PRODUCT": "YES",
    })
    common_target = {
        "CODE_SIGN_STYLE": "Automatic", "CODE_SIGNING_ALLOWED[sdk=iphonesimulator*]": "NO",
        "CURRENT_PROJECT_VERSION": "1", "GENERATE_INFOPLIST_FILE": "YES",
        "MARKETING_VERSION": "1.0", "PRODUCT_NAME": "$(TARGET_NAME)",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "SUPPORTS_MACCATALYST": "NO",
        "TARGETED_DEVICE_FAMILY": "1,2", "SWIFT_EMIT_LOC_STRINGS": "YES",
    }
    app_configs = configurations("app", {
        **common_target,
        "PRODUCT_BUNDLE_IDENTIFIER": "com.plurifold.ios.prototype",
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "INFOPLIST_KEY_CFBundleDisplayName": "Plurifold",
        "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption": "NO",
        "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.education",
        "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
        "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
        "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
    }, {}, {})
    test_configs = configurations("tests", {
        **common_target,
        "PRODUCT_BUNDLE_IDENTIFIER": "com.plurifold.ios.prototype.tests",
        "BUNDLE_LOADER": "$(TEST_HOST)",
        "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/Plurifold.app/Plurifold",
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks"],
    }, {}, {})

    app_target = add("target:app", "PBXNativeTarget", buildConfigurationList=app_configs,
                     buildPhases=app_phases, buildRules=[], dependencies=[], name="Plurifold",
                     productName="Plurifold", productReference=app_product,
                     productType="com.apple.product-type.application")
    proxy = add("proxy:tests-to-app", "PBXContainerItemProxy", containerPortal=identifier("project"),
                proxyType=1, remoteGlobalIDString=app_target, remoteInfo="Plurifold")
    dependency = add("dependency:tests-to-app", "PBXTargetDependency", target=app_target, targetProxy=proxy)
    test_target = add("target:tests", "PBXNativeTarget", buildConfigurationList=test_configs,
                      buildPhases=test_phases, buildRules=[], dependencies=[dependency],
                      name="PlurifoldTests", productName="PlurifoldTests", productReference=test_product,
                      productType="com.apple.product-type.bundle.unit-test")
    project = add("project", "PBXProject", attributes={
        "BuildIndependentTargetsInParallel": "YES", "LastUpgradeCheck": "1500",
        "TargetAttributes": {app_target: {"CreatedOnToolsVersion": "15.0"},
                              test_target: {"CreatedOnToolsVersion": "15.0", "TestTargetID": app_target}},
    }, buildConfigurationList=project_configs, compatibilityVersion="Xcode 14.0",
        developmentRegion="en", hasScannedForEncodings=0, knownRegions=["en", "Base"],
        mainGroup=root_group, productRefGroup=products, projectDirPath="", projectRoot="",
        targets=[app_target, test_target])
    validate_graph()
    PROJECT.mkdir(parents=True, exist_ok=True)
    document = {"archiveVersion": 1, "classes": {}, "objectVersion": 56,
                "objects": OBJECTS, "rootObject": project}
    (PROJECT / "project.pbxproj").write_text("// !$*UTF8*$!\n" + serialize(document) + "\n", encoding="utf-8")
    write_scheme(app_target, test_target)
    print(f"Generated {PROJECT.name}: {len(app_sources)} app sources, "
          f"{len(test_sources)} test sources, {len(resources)} resources; "
          f"validated {len(OBJECTS)} object references.")


if __name__ == "__main__":
    main()
