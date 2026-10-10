/// 초대/딥링크가 사용하는 웹 호스트. Netlify 정적 사이트(App Links 검증)와 일치해야 함.
/// 커스텀 도메인으로 전환할 때 이 상수들만 바꾸면 된다.
const String kInviteLinkHost = 'tripmaptrace.netlify.app';
const String kInviteLinkBase = 'https://$kInviteLinkHost';

/// 초대 토큰으로 공유용 https 링크를 만든다. (App Links 로 앱이 가로챔)
String buildInviteUrl(String token) => '$kInviteLinkBase/invite/$token';
