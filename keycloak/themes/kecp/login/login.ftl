<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('username','password') displayInfo=true; section>
    <#if section = "header">
        <#-- K-ECP 로고 -->
        <div class="kecp-logo-container">
            <img src="${url.resourcesPath}/img/kecp-logo.svg" alt="K-ECP KDN Energy Cloud Platform" class="kecp-logo" />
        </div>
    <#elseif section = "form">
        <div id="kc-form">
            <div id="kc-form-wrapper">
                <#if realm.password>
                    <form id="kc-form-login" onsubmit="login.disabled = true; return true;" action="${url.loginAction}" method="post">
                        <#-- 에러 메시지 -->
                        <#if messagesPerField.existsError('username','password')>
                            <div class="alert-error">
                                ${kcSanitize(messagesPerField.getFirstError('username','password'))?no_esc}
                            </div>
                        </#if>

                        <#if !usernameHidden??>
                            <div class="form-group">
                                <input tabindex="1" id="username" name="username" value="${(login.username!'')}" type="text" autofocus autocomplete="off"
                                       placeholder="${msg('usernamePlaceholder')}"
                                />
                            </div>
                        </#if>

                        <div class="form-group">
                            <input tabindex="2" id="password" name="password" type="password" autocomplete="off"
                                   placeholder="${msg('passwordPlaceholder')}"
                            />
                        </div>

                        <#-- 아이디 저장 체크박스 -->
                        <#if realm.rememberMe && !usernameHidden??>
                            <div id="kc-form-options">
                                <div class="checkbox">
                                    <label>
                                        <#if login.rememberMe??>
                                            <input tabindex="3" id="rememberMe" name="rememberMe" type="checkbox" checked>
                                        <#else>
                                            <input tabindex="3" id="rememberMe" name="rememberMe" type="checkbox">
                                        </#if>
                                        ${msg("rememberMe")}
                                    </label>
                                </div>
                            </div>
                        </#if>

                        <#-- 로그인 버튼 -->
                        <div id="kc-form-buttons">
                            <input type="hidden" id="id-hidden-input" name="credentialId" <#if auth.selectedCredential?has_content>value="${auth.selectedCredential}"</#if>/>
                            <input tabindex="4" id="kc-login" type="submit" value="${msg("doLogIn")}"/>
                        </div>

                        <#-- 회원가입 버튼 -->
                        <a tabindex="5" href="http://localhost:4000/register" class="kecp-register-btn">${msg("doRegister")}</a>

                        <#-- 아이디 찾기 | 비밀번호 찾기 -->
                        <div class="kecp-bottom-links">
                            <a href="http://localhost:4000/find-id">${msg("findId")}</a>
                            <span class="divider">|</span>
                            <a href="http://localhost:4000/forgot-password">${msg("findPassword")}</a>
                        </div>
                    </form>
                </#if>
            </div>
        </div>
    </#if>
</@layout.registrationLayout>
