set(SSG_SHARED "${CMAKE_SOURCE_DIR}/shared")
set(SSG_SHARED_TRANSFORMS "${SSG_SHARED}/transforms")
set(SSG_SHARED_UTILS "${SSG_SHARED}/utils")
set(SSG_SHARED_REMEDIATIONS "${SSG_SHARED}/templates/static/bash")

macro(ssg_build_guide_xml PRODUCT)
    if(OSCAP_SVG_SUPPORT EQUAL 0)
        add_custom_command(
            OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/guide.xml
            COMMAND ${XSLTPROC_EXECUTABLE} --output ${CMAKE_CURRENT_BINARY_DIR}/guide.xml ${SSG_SHARED_TRANSFORMS}/includelogo.xslt ${CMAKE_CURRENT_SOURCE_DIR}/input/guide.xml
            MAIN_DEPENDENCY ${CMAKE_CURRENT_SOURCE_DIR}/input/guide.xml
            DEPENDS ${SSG_SHARED_TRANSFORMS}/includelogo.xslt
            COMMENT "[${PRODUCT}] generating guide.xml (SVG logo enabled)"
        )
    else()
        add_custom_command(
            OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/guide.xml
            COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/input/guide.xml ${CMAKE_CURRENT_BINARY_DIR}/guide.xml
            MAIN_DEPENDENCY ${CMAKE_CURRENT_SOURCE_DIR}/input/guide.xml
            COMMENT "[${PRODUCT}] generating guide.xml (SVG logo disabled)"
        )
    endif()
endmacro()

macro(ssg_build_shorthand_xml PRODUCT)
    file(GLOB AUXILIARY_DEPS "${CMAKE_CURRENT_SOURCE_DIR}/input/auxiliary/*.xml")
    file(GLOB PROFILE_DEPS "${CMAKE_CURRENT_SOURCE_DIR}/input/profiles/*.xml")
    file(GLOB XCCDF_RULE_DEPS "${CMAKE_CURRENT_SOURCE_DIR}/input/xccdf/**/*.xml")

    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/shorthand.xml
        COMMAND ${XSLTPROC_EXECUTABLE} --stringparam SHARED_RP ${SSG_SHARED} --output ${CMAKE_CURRENT_BINARY_DIR}/shorthand.xml ${CMAKE_CURRENT_SOURCE_DIR}/input/guide.xslt ${CMAKE_CURRENT_BINARY_DIR}/guide.xml
        COMMAND ${XMLLINT_EXECUTABLE} --format --output ${CMAKE_CURRENT_BINARY_DIR}/shorthand.xml ${CMAKE_CURRENT_BINARY_DIR}/shorthand.xml
        MAIN_DEPENDENCY ${CMAKE_CURRENT_BINARY_DIR}/guide.xml
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/input/guide.xslt ${AUXILIARY_DEPS} ${PROFILE_DEPS} ${XCCDF_RULE_DEPS}
        COMMENT "[${PRODUCT}] generating shorthand.xml"
    )
endmacro()

macro(ssg_build_unlinked_xccdf PRODUCT)
    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/xccdf-unlinked-resolved.xml
        COMMAND ${XSLTPROC_EXECUTABLE} --stringparam ssg_version ${SSG_VERSION} --output ${CMAKE_CURRENT_BINARY_DIR}/xccdf-unlinked-resolved.xml ${CMAKE_CURRENT_SOURCE_DIR}/transforms/shorthand2xccdf.xslt ${CMAKE_CURRENT_BINARY_DIR}/shorthand.xml
        COMMAND ${OSCAP_EXECUTABLE} xccdf resolve -o ${CMAKE_CURRENT_BINARY_DIR}/xccdf-unlinked-resolved.xml ${CMAKE_CURRENT_BINARY_DIR}/xccdf-unlinked-resolved.xml
        COMMAND ${SSG_SHARED_UTILS}/unselect-empty-xccdf-groups.py --input ${CMAKE_CURRENT_BINARY_DIR}/xccdf-unlinked-resolved.xml --output ${CMAKE_CURRENT_BINARY_DIR}/xccdf-unlinked-resolved.xml
        COMMAND ${OSCAP_EXECUTABLE} xccdf resolve -o ${CMAKE_CURRENT_BINARY_DIR}/xccdf-unlinked-resolved.xml ${CMAKE_CURRENT_BINARY_DIR}/xccdf-unlinked-resolved.xml
        MAIN_DEPENDENCY ${CMAKE_CURRENT_BINARY_DIR}/shorthand.xml
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/transforms/shorthand2xccdf.xslt ${CMAKE_CURRENT_SOURCE_DIR}/transforms/constants.xslt ${SSG_SHARED_TRANSFORMS}/shared_constants.xslt
        #DEPENDS ${CMAKE_BINARY_DIR}/contributors.xml
        COMMENT "[${PRODUCT}] generating xccdf-unlinked-resolved.xml"
    )
endmacro()

macro(ssg_build_unlinked_ocil PRODUCT)
    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/ocil-unlinked.xml
        COMMAND ${XSLTPROC_EXECUTABLE} --output ${CMAKE_CURRENT_BINARY_DIR}/ocil-unlinked.xml ${SSG_SHARED_TRANSFORMS}/xccdf-create-ocil.xslt ${CMAKE_CURRENT_BINARY_DIR}/xccdf-unlinked-resolved.xml
        COMMAND ${XMLLINT_EXECUTABLE} --format --output ${CMAKE_CURRENT_BINARY_DIR}/ocil-unlinked.xml ${CMAKE_CURRENT_BINARY_DIR}/ocil-unlinked.xml
        MAIN_DEPENDENCY ${CMAKE_CURRENT_BINARY_DIR}/xccdf-unlinked-resolved.xml
        DEPENDS ${SSG_SHARED_TRANSFORMS}/xccdf-create-ocil.xslt
        COMMENT "[${PRODUCT}] generating ocil-unlinked.xml"
    )
endmacro()

macro(ssg_build_xccdf_ocilrefs PRODUCT)
    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/xccdf-unlinked-ocilrefs.xml
        COMMAND ${XSLTPROC_EXECUTABLE} --stringparam product ${PRODUCT} --output ${CMAKE_CURRENT_BINARY_DIR}/xccdf-unlinked-ocilrefs.xml ${SSG_SHARED_TRANSFORMS}/xccdf-ocilcheck2ref.xslt ${CMAKE_CURRENT_BINARY_DIR}/xccdf-unlinked-resolved.xml
        MAIN_DEPENDENCY ${CMAKE_CURRENT_BINARY_DIR}/xccdf-unlinked-resolved.xml
        DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/ocil-unlinked.xml ${SSG_SHARED_TRANSFORMS}/xccdf-ocilcheck2ref.xslt
        COMMENT "[${PRODUCT}] generating xccdf-unlinked-ocilrefs.xml"
    )
endmacro()

macro(ssg_build_bash_remediations PRODUCT)
    file(GLOB BASH_REMEDIATION_DEPS "${CMAKE_CURRENT_SOURCE_DIR}/templates/static/bash/*.sh")
    file(GLOB SHARED_BASH_REMEDIATION_DEPS "${SSG_SHARED_REMEDIATIONS}/*.sh")

    # TODO: The environment variable is not very portable
    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/bash-remediations.xml
        COMMAND SHARED=${SSG_SHARED} ${SSG_SHARED_TRANSFORMS}/combineremediations.py ${PRODUCT} ${SSG_SHARED_REMEDIATIONS} ${CMAKE_CURRENT_SOURCE_DIR}/templates/static/bash ${CMAKE_CURRENT_BINARY_DIR}/bash-remediations.xml
        DEPENDS ${BASH_REMEDIATION_DEPS} ${SHARED_BASH_REMEDIATION_DEPS}
        COMMENT "[${PRODUCT}] generating bash-remediations.xml"
    )
endmacro()

macro(ssg_build_xccdf_with_remediations PRODUCT)
    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/xccdf-unlinked-withremediations.xml
        COMMAND ${XSLTPROC_EXECUTABLE} --stringparam remediations ${CMAKE_CURRENT_BINARY_DIR}/bash-remediations.xml --output ${CMAKE_CURRENT_BINARY_DIR}/xccdf-unlinked-withremediations.xml ${SSG_SHARED_TRANSFORMS}/xccdf-addremediations.xslt ${CMAKE_CURRENT_BINARY_DIR}/xccdf-unlinked-ocilrefs.xml
        COMMAND ${XMLLINT_EXECUTABLE} --format --output ${CMAKE_CURRENT_BINARY_DIR}/xccdf-unlinked-ocilrefs.xml ${CMAKE_CURRENT_BINARY_DIR}/xccdf-unlinked-ocilrefs.xml
        MAIN_DEPENDENCY ${CMAKE_CURRENT_BINARY_DIR}/xccdf-unlinked-ocilrefs.xml
        DEPENDS ${SSG_SHARED_TRANSFORMS}/xccdf-addremediations.xslt ${CMAKE_CURRENT_BINARY_DIR}/bash-remediations.xml
        COMMENT "[${PRODUCT}] generating xccdf-unlinked-withremediations.xml"
    )
endmacro()

macro(ssg_build_unlinked_oval PRODUCT)
    set(OVAL_DEPS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/input/oval")
    file(GLOB OVAL_DEPS "${OVAL_DEPS_DIR}/*.xml")
    set(SHARED_OVAL_DEPS_DIR "${SSG_SHARED}/oval")
    file(GLOB SHARED_OVAL_DEPS "${SHARED_OVAL_DEPS_DIR}/*.xml")

    if(OSCAP_OVAL_511_SUPPORT EQUAL 0)
        set(OVAL_511_DEPS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/input/oval/oval_5.11")
        file(GLOB OVAL_511_DEPS "${OVAL_511_DEPS_DIR}/*.xml")
        set(SHARED_OVAL_511_DEPS_DIR "${SSG_SHARED}/oval/oval_5.11")
        file(GLOB SHARED_OVAL_511_DEPS "${SHARED_OVAL_511_DEPS_DIR}/*.xml")

        add_custom_command(
            OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/unlinked-oval.xml
            # TODO: config
            COMMAND RUNTIME_OVAL_VERSION=5.11 ${SSG_SHARED_TRANSFORMS}/combineovals.py ${CMAKE_SOURCE_DIR}/config ${PRODUCT} ${OVAL_DEPS_DIR} ${OVAL_511_DEPS_DIR} ${SHARED_OVAL_DEPS_DIR} ${SHARED_OVAL_511_DEPS_DIR} > ${CMAKE_CURRENT_BINARY_DIR}/unlinked-oval.xml
            COMMAND ${XMLLINT_EXECUTABLE} --format --output ${CMAKE_CURRENT_BINARY_DIR}/unlinked-oval.xml ${CMAKE_CURRENT_BINARY_DIR}/unlinked-oval.xml
            DEPENDS ${OVAL_DEPS}
            DEPENDS ${OVAL_511_DEPS}
            DEPENDS ${SHARED_OVAL_DEPS}
            DEPENDS ${SHARED_OVAL_511_DEPS}
            VERBATIM
            COMMENT "[${PRODUCT}] generating unlinked-oval.xml (OVAL 5.11 checks enabled)"
        )
    else()
        add_custom_command(
            OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/unlinked-oval.xml
            # TODO: config
            COMMAND ${SSG_SHARED_TRANSFORMS}/combineovals.py ${CMAKE_SOURCE_DIR}/config ${PRODUCT} ${OVAL_DEPS_DIR} ${SHARED_OVAL_DEPS_DIR} > ${CMAKE_CURRENT_BINARY_DIR}/unlinked-oval.xml
            COMMAND ${XMLLINT_EXECUTABLE} --format --output ${CMAKE_CURRENT_BINARY_DIR}/unlinked-oval.xml ${CMAKE_CURRENT_BINARY_DIR}/unlinked-oval.xml
            DEPENDS ${OVAL_DEPS}
            DEPENDS ${SHARED_OVAL_DEPS}
            VERBATIM
            COMMENT "[${PRODUCT}] generating unlinked-oval.xml (OVAL 5.11 checks disabled)"
        )
    endif()
endmacro()

macro(ssg_build_product PRODUCT)
    ssg_build_guide_xml(${PRODUCT})
    ssg_build_shorthand_xml(${PRODUCT})
    ssg_build_unlinked_xccdf(${PRODUCT})
    ssg_build_unlinked_ocil(${PRODUCT})
    ssg_build_xccdf_ocilrefs(${PRODUCT})
    ssg_build_bash_remediations(${PRODUCT})
    ssg_build_xccdf_with_remediations(${PRODUCT})
    ssg_build_unlinked_oval(${PRODUCT})
endmacro()
