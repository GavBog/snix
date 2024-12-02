Received: by 2002:a05:6838:9619:0:0:0:0 with SMTP id y25csp3021959nkj;
        Sun, 27 Sep 2020 16:35:15 -0700 (PDT)
X-Received: by 2002:a05:6402:396:: with SMTP id o22mr12644027edv.316.1601249714826;
        Sun, 27 Sep 2020 16:35:14 -0700 (PDT)
ARC-Seal: i=3; a=rsa-sha256; t=1601249714; cv=pass;
        d=google.com; s=arc-20160816;
        b=JZF8xwEI+NfpPypYuVsDwKKN4In4Gxk3qcvm260gDbKPo04eS7Dn3CcoeQkbB3Ryck
         FUtB8PfISQOsDboMeEXqGbhbCSbH2HoXWySM6XucTVzfeL2hXF9sPjFUCx6LLuvSDSxL
         7E146B7H3dNvB1ndqkWyefiVeSgeES7KzVvYbkoMJJlKozR6FUsKMCVMdrRq0ja6iGbf
         7TlLWvlci49+8LZQKtDQ2ovU/DSQmu2f7eWcbozsIP3ArBxQ+814bQprLWQYsI5Z4fZz
         0kPEC6dbZpajPDNpTx5ark/+EV/ICGVE6kODmNjFTi18eMjMU1PXULE8FImkw+duFdzP
         DF4g==
ARC-Message-Signature: i=3; a=rsa-sha256; c=relaxed/relaxed; d=google.com; s=arc-20160816;
        h=list-unsubscribe:list-subscribe:list-archive:list-help:list-post
         :list-id:mailing-list:precedence:subject:to:from:date:message-id
         :mime-version:user-agent:sender:dkim-signature;
        bh=2VC221ICpWr3atnjvjQBr2VGuwcTNaQLBA5EJvQxzNE=;
        b=oI1vj3HEqVB2vRTlg44B8ik+G5jSMm7YHiPOdg+oWwiZSeK1DlKf3S0C9brs8iLBDU
         paovJkxdJu++lY1zzBorw34bMDPHsfnBf6ztDZfAhpDSQM3VZEW+jAvAc9vFh6eL5ilE
         qdZR9blzrqoi5GoPmVx7j/Z30zFidppWNbZLzuC7pAcS86WzKd8Ta56EDxxHE48RFRyO
         TYhIonS2QEBp+Yn2Pm5SGez/5HHI2s3vu1kXTZ0JKETvWSkZUtBsX7u7KTfcy3EAjvc8
         3s2dxQpMCYXZvyvJ0g2k0dsecEDRBWa2gv9Wr3iip7v5NaRcKuz1nuN/AiazKZPTDION
         f/tg==
ARC-Authentication-Results: i=3; mx.google.com;
       dkim=pass header.i=@tazj.in header.s=google header.b=dVeQt6cm;
       arc=pass (i=2 dkim=pass dkdomain=firefly.nu dkim=pass dkdomain=messagingengine.com);
       spf=pass (google.com: domain of depot+bncbdhlpx4g2ierbmwdyt5qkgqexgc7sqy@tazj.in designates 209.85.220.69 as permitted sender) smtp.mailfrom=depot+bncBDHLPX4G2IERBMWDYT5QKGQEXGC7SQY@tazj.in
Return-Path: <depot+bncBDHLPX4G2IERBMWDYT5QKGQEXGC7SQY@tazj.in>
Received: from mail-sor-f69.google.com (mail-sor-f69.google.com. [209.85.220.69])
        by mx.google.com with SMTPS id li22sor4242657ejb.49.2020.09.27.16.35.14
        for <mail@tazj.in>
        (Google Transport Security);
        Sun, 27 Sep 2020 16:35:14 -0700 (PDT)
Received-SPF: pass (google.com: domain of depot+bncbdhlpx4g2ierbmwdyt5qkgqexgc7sqy@tazj.in designates 209.85.220.69 as permitted sender) client-ip=209.85.220.69;
Authentication-Results: mx.google.com;
       dkim=pass header.i=@tazj.in header.s=google header.b=dVeQt6cm;
       arc=pass (i=2 dkim=pass dkdomain=firefly.nu dkim=pass dkdomain=messagingengine.com);
       spf=pass (google.com: domain of depot+bncbdhlpx4g2ierbmwdyt5qkgqexgc7sqy@tazj.in designates 209.85.220.69 as permitted sender) smtp.mailfrom=depot+bncBDHLPX4G2IERBMWDYT5QKGQEXGC7SQY@tazj.in
ARC-Seal: i=2; a=rsa-sha256; t=1601249714; cv=pass;
        d=google.com; s=arc-20160816;
        b=e/oahP75xCAPQvP5D7B1dG2SDAEC5XNRI40cafqhXEI32hdW9TQNSs1krZ7tQHOht2
         /ZGbOLY/BNxS3VoDM+Mcif7BCx7bjeOpmVkVzEhM0KZoBHorf91SOBM05PvewA9nQtLb
         1pXB8bdivzOkYUuSX56rX1sOjNjMrWWUPF8Ven5zy3r2MIqJ561O8pPN/6Uz0tajiK7Y
         klavaIk/Pxo91kuVbOKDJTH2mmggFTthqYkkCQuelgeKx4zBdDjS32vx3kPLRhMnfuGu
         +CHC9L2Gv0ww0PyfRhkYeNLRrAqVHWDyCrw26f2QxFBEoTv/OnzH380uqO9n+SdmILBI
         fNzw==
ARC-Message-Signature: i=2; a=rsa-sha256; c=relaxed/relaxed; d=google.com; s=arc-20160816;
        h=list-unsubscribe:list-subscribe:list-archive:list-help:list-post
         :list-id:mailing-list:precedence:subject:to:from:date:message-id
         :mime-version:user-agent:sender:dkim-signature;
        bh=2VC221ICpWr3atnjvjQBr2VGuwcTNaQLBA5EJvQxzNE=;
        b=BONPbsQkjSVRgH8pu89B9aXx6IAuchsgfp2pedA7kEz7Gw3/M9nQoPxTbjcAXKFWoi
         SDqYH/Ch6TrYFy6WmgKyw5NB0WuB6WIC9jhRbeiGsXlxbnm1cP1thD7uRFJTaAhcaRBO
         cbRA5Ue7pTphAtNVWkHeC37swSOrLtl9WFj+vXwo2l8ndO+5uP6jBi3ApaZDXyx7NODT
         i3Jo1kehj7rnA+PINKR8tjlZ1COJYmxWz7upypJY4rZxLdJYzXPS19Rdhq4zmumyqRxt
         NsnIIPsPRnYopcLd15rwgSOaHYi4CWwalkpfsBL1IaKXuk0K/XwmLsWdGrNRAN4aUEoR
         7KEw==
ARC-Authentication-Results: i=2; mx.google.com;
       dkim=pass header.i=@firefly.nu header.s=fm2 header.b=P5Ezbo3T;
       dkim=pass header.i=@messagingengine.com header.s=fm3 header.b=pHVhf6X0;
       spf=neutral (google.com: 64.147.123.21 is neither permitted nor denied by best guess record for domain of firefly@firefly.nu) smtp.mailfrom=firefly@firefly.nu
DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed;
        d=tazj.in; s=google;
        h=sender:user-agent:mime-version:message-id:date:from:to:subject
         :x-original-sender:x-original-authentication-results:precedence
         :mailing-list:list-id:list-post:list-help:list-archive
         :list-subscribe:list-unsubscribe;
        bh=2VC221ICpWr3atnjvjQBr2VGuwcTNaQLBA5EJvQxzNE=;
        b=dVeQt6cmfZBkKqjl826gk0BnxKVtl6OsjaldzCuNQxqxhrecw9GbSofGqS3WxrxWWP
         S8cg2AoRtIFC8nuTiRCAEgREb+4paYH5BtDbLtL/Y56jOA0djb6APwYx8MYOVwQxflrx
         yyGWSXI04MYjkX/+0gFyvzi0VfZM4UK4pjfPN6WhHBe4xy6bF8VBds11PPAaKZdSdAvR
         z8j+CpWBNzKNfbM3bUdLbEuPmt3+Qeem/4HAnRhY6jIYyBJb2a2vXT/edBasnTE/gNSd
         Cf4SppE7H3EpRwveBAF367MeeX3stQrXN//t2aXljnuxymM90yPkIq2Xn0zBfp1O47WR
         aOBg==
X-Google-DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed;
        d=1e100.net; s=20161025;
        h=sender:x-gm-message-state:user-agent:mime-version:message-id:date
         :from:to:subject:x-original-sender:x-original-authentication-results
         :precedence:mailing-list:list-id:x-spam-checked-in-group:list-post
         :list-help:list-archive:list-subscribe:list-unsubscribe;
        bh=2VC221ICpWr3atnjvjQBr2VGuwcTNaQLBA5EJvQxzNE=;
        b=qScRnwtHSE4Boeu7UpmdBjsVhesvMMFHVmdPjW3sNCgR1SxUIOLjFpJNPXy/l+dlOh
         sApL/oDMQ25yHodkQF8G2mRCV+SBDVAsrIo0w+LILPP3h+Y0y2yTLiLwKE4WLqoaPi1l
         jugZUthJC3KEHq8fhtQHRTtBc5V7UQJIecH2kIU43DUNKpzkzOdf7km6Q0cY9CdXs23x
         PSuSg4PzbHOo6cGdBVKvbsjh+sOn6WFuxoXOTtNmFJfE9fTfUlz7LJumTZU3J7DKc5Ho
         aYzHFmRwdZUyoX/FQwT//Tf2RQbnVGD3o5a+6lhzt8MFecmLHvRImbKCL/L8K+WTYYFY
         ou0g==
Sender: depot@tazj.in
X-Gm-Message-State: AOAM530ZJ8ZcOIvD5lsuI9DM+tccfbSnX8Qgkk03neyoDAKpidBSMC/W
	yt/uGXfgEMSbcEOWEu/zxLqwyI0F
X-Google-Smtp-Source: ABdhPJySQZLzFZhvk2VQDhHrXOWbCQqFMNYvDodhQIOIvOgRkT6bOuvTGVrWIiY58v2NVvIzUZCfKw==
X-Received: by 2002:a17:906:d78c:: with SMTP id pj12mr12868809ejb.36.1601249714531;
        Sun, 27 Sep 2020 16:35:14 -0700 (PDT)
X-BeenThere: depot@tazj.in
Received: by 2002:a17:906:547:: with SMTP id k7ls3670922eja.7.gmail; Sun, 27
 Sep 2020 16:35:13 -0700 (PDT)
X-Received: by 2002:a17:906:2cd2:: with SMTP id r18mr13573990ejr.371.1601249713549;
        Sun, 27 Sep 2020 16:35:13 -0700 (PDT)
ARC-Seal: i=1; a=rsa-sha256; t=1601249713; cv=none;
        d=google.com; s=arc-20160816;
        b=oi0sYnQxS35/hNyKRgiTTgLNV0zvOtiE8Irv6bfmQCOADDql9vaDvs430N+tsEzON3
         wd8frXphZvgkZjVvPer5CgLyr84ixyrrHhEDwqs89AYR9wHibQ6QtinQfr5xoDkQW9Tb
         MMlgl55c2AHzXXqe+eY4gEHww/y8ys1aCDAWEhGxe1M09FiUVBn3+F2ZOV5IW4q+p9TW
         EMPNZyByXAZnqkYZCX+KHJ+3nyuQ0PsRVuIVbQA/a0GvVwl+yEhyJno7l2AUR8cfl8at
         MeevKmvuYTCuc03cLceleXov097xsF0WvO8H68OPkZj1Kf9wrE3qg6avyZF285ixaXrS
         Kc6A==
ARC-Message-Signature: i=1; a=rsa-sha256; c=relaxed/relaxed; d=google.com; s=arc-20160816;
        h=subject:to:from:date:message-id:mime-version:user-agent
         :dkim-signature:dkim-signature;
        bh=RahJwSWaN3jErVsNLXnMXbf7yUdzKHDGCF4swc44ayM=;
        b=qzsApa+4gOUyfT8CcBmrz26QKrvOy54oZgzrHdDe7oNkLANtUyxqKD3KhDAKGUMLYQ
         jbXSNrQnhNR4GUNAYmpT/TM0RnbEgdO9rr9LcA3pGA9/LuJo3jBkV87a9H7cC5mp8Zwc
         sL4WScovJaK7m0m83VBDqq9Zhp0hexHCKCnH/LrNtpTrWiQvYz6BuDM04BuOEXN4mq1c
         tXXcDsrcoj4hTLtGplWU5qGhYnem00cKPXsQ09ivGKFib1TbNgiVGsnHrICktmmionRw
         SioEgIoc0ZUlHQOvoV0UlbkCAEEPS9GBR3NeTbm+Dth08zejgs+Il9QiFV2kLnJ0QMpn
         oB8A==
ARC-Authentication-Results: i=1; mx.google.com;
       dkim=pass header.i=@firefly.nu header.s=fm2 header.b=P5Ezbo3T;
       dkim=pass header.i=@messagingengine.com header.s=fm3 header.b=pHVhf6X0;
       spf=neutral (google.com: 64.147.123.21 is neither permitted nor denied by best guess record for domain of firefly@firefly.nu) smtp.mailfrom=firefly@firefly.nu
Received: from wout5-smtp.messagingengine.com (wout5-smtp.messagingengine.com. [64.147.123.21])
        by mx.google.com with ESMTPS id m23si6276235ejo.333.2020.09.27.16.35.13
        for <depot@tazj.in>
        (version=TLS1_2 cipher=ECDHE-ECDSA-AES128-GCM-SHA256 bits=128/128);
        Sun, 27 Sep 2020 16:35:13 -0700 (PDT)
Received-SPF: neutral (google.com: 64.147.123.21 is neither permitted nor denied by best guess record for domain of firefly@firefly.nu) client-ip=64.147.123.21;
Received: from compute1.internal (compute1.nyi.internal [10.202.2.41])
	by mailout.west.internal (Postfix) with ESMTP id AF9D4858
	for <depot@tazj.in>; Sun, 27 Sep 2020 19:35:11 -0400 (EDT)
Received: from imap6 ([10.202.2.56])
  by compute1.internal (MEProxy); Sun, 27 Sep 2020 19:35:11 -0400
X-ME-Sender: <xms:riFxX4VnnifQ9w1KFMktbNIetMCUOiNsY4QMYMYNlcgQgeqXmCbxGg>
    <xme:riFxX8mtBTwZaJ30GiNT2TYs0ejG-tC5fKpxry_tax2FN1_w3MP63qO7Ffo4aMcuK
    eqmL1zZSYwS6hK6BvU>
X-ME-Proxy-Cause: gggruggvucftvghtrhhoucdtuddrgedujedrvdehgddvfecutefuodetggdotefrodftvf
    curfhrohhfihhlvgemucfhrghsthforghilhdpqfgfvfdpuffrtefokffrpgfnqfghnecu
    uegrihhlohhuthemuceftddtnecunecujfgurhepofgfggfkfffhvffutgesmhdtreerre
    ertdenucfhrhhomhephfhirhgvhfhlhicuoehfihhrvghflhihsehfihhrvghflhihrdhn
    uheqnecuggftrfgrthhtvghrnhepgfejjeeivdduheehhffgiedvvdeivefhfeekhfejvd
    fgleekffdtvefgtdeuheefnecuvehluhhsthgvrhfuihiivgeptdenucfrrghrrghmpehm
    rghilhhfrhhomhepfhhirhgvfhhlhiesfhhirhgvfhhlhidrnhhu
X-ME-Proxy: <xmx:riFxX8bsOSPgAJy1KyePkpmeGpo8_4ECkIYua3cdRGhJD45-GomP8Q>
    <xmx:riFxX3Ugz0lVIhmd_81eDzJj-2szxZvctDBqkrSaqBZ_TDOMs1VupQ>
    <xmx:riFxXym0eSIOSeILjv9B21LhstreNAqMkiGciBVaC2LtNcaTVGm6wg>
    <xmx:ryFxX4k9Fcb8iNBf12VTr02XeILIeJsjVJ3N-5Zb8vvkAOQ9acbwRQ>
Received: by mailuser.nyi.internal (Postfix, from userid 501)
	id AEA2C1400D7; Sun, 27 Sep 2020 19:35:10 -0400 (EDT)
X-Mailer: MessagingEngine.com Webmail Interface
User-Agent: Cyrus-JMAP/3.3.0-355-g3ece53b-fm-20200922.004-g3ece53b9
Mime-Version: 1.0
Message-Id: <4f4614f5-23dc-4263-b506-c557588232b2@www.fastmail.com>
Date: Mon, 28 Sep 2020 01:34:48 +0200
From: FireFly <firefly@firefly.nu>
To: depot@tazj.in
Subject: [PATCH] feat(tvl-slapd): add firefly
Content-Type: multipart/mixed;
 boundary=07c9605219da4b40b95ea5a855089bfa
X-Original-Sender: firefly@firefly.nu
X-Original-Authentication-Results: mx.google.com;       dkim=pass
 header.i=@firefly.nu header.s=fm2 header.b=P5Ezbo3T;       dkim=pass
 header.i=@messagingengine.com header.s=fm3 header.b=pHVhf6X0;
       spf=neutral (google.com: 64.147.123.21 is neither permitted nor denied
 by best guess record for domain of firefly@firefly.nu) smtp.mailfrom=firefly@firefly.nu
Precedence: list
Mailing-list: list depot@tazj.in; contact depot+owners@tazj.in
List-ID: <depot.tazj.in>
X-Spam-Checked-In-Group: depot@tazj.in
X-Google-Group-Id: 728837484537
List-Post: <https://groups.google.com/a/tazj.in/group/depot/post>, <mailto:depot@tazj.in>
List-Help: <https://support.google.com/a/tazj.in/bin/topic.py?topic=25838>, <mailto:depot+help@tazj.in>
List-Archive: <https://groups.google.com/a/tazj.in/group/depot/>
List-Subscribe: <https://groups.google.com/a/tazj.in/group/depot/subscribe>, <mailto:depot+subscribe@tazj.in>
List-Unsubscribe: <mailto:googlegroups-manage+728837484537+unsubscribe@googlegroups.com>,
 <https://groups.google.com/a/tazj.in/group/depot/subscribe>

--07c9605219da4b40b95ea5a855089bfa
Content-Type: text/plain; charset="UTF-8"

Adding an account for myself


--07c9605219da4b40b95ea5a855089bfa
Content-Disposition: attachment;filename="0001-feat-tvl-slapd-add-firefly.patch"
Content-Type: application/octet-stream; name="0001-feat-tvl-slapd-add-firefly.patch"
Content-Transfer-Encoding: BASE64

RnJvbSA4ZDNiNmI5NWQ0Y2RlMDNmM2I2MjQzZmYyYWJhYmQ0YTEzNDhjZmUzIE1vbiBTZXAg
MTcgMDA6MDA6MDAgMjAwMQpGcm9tOiA9P1VURi04P3E/Sm9uYXM9MjBIPUMzPUI2Z2x1bmQ/
PSA8ZmlyZWZseUBmaXJlZmx5Lm51PgpEYXRlOiBNb24sIDI4IFNlcCAyMDIwIDAxOjI4OjI5
ICswMjAwClN1YmplY3Q6IFtQQVRDSF0gZmVhdCh0dmwtc2xhcGQpOiBhZGQgZmlyZWZseQoK
LS0tCiBvcHMvbml4b3MvdHZsLXNsYXBkL2RlZmF1bHQubml4IHwgNSArKysrKwogMSBmaWxl
IGNoYW5nZWQsIDUgaW5zZXJ0aW9ucygrKQoKZGlmZiAtLWdpdCBhL29wcy9uaXhvcy90dmwt
c2xhcGQvZGVmYXVsdC5uaXggYi9vcHMvbml4b3MvdHZsLXNsYXBkL2RlZmF1bHQubml4Cmlu
ZGV4IDQyMGU4ZTE5Ni4uMzk3N2ZjNzkyIDEwMDY0NAotLS0gYS9vcHMvbml4b3MvdHZsLXNs
YXBkL2RlZmF1bHQubml4CisrKyBiL29wcy9uaXhvcy90dmwtc2xhcGQvZGVmYXVsdC5uaXgK
QEAgLTYwLDYgKzYwLDExIEBAIGxldAogICAgICAgZW1haWwgPSAiZXRhQHRoZXRhLmV1Lm9y
ZyI7CiAgICAgICBwYXNzd29yZCA9ICJ7U1NIQX1zT1I1eHppN0xmdjM3NlhHUUE4SGY2anlo
VHZvMFhZYyI7CiAgICAgfQorICAgIHsKKyAgICAgIHVzZXJuYW1lID0gImZpcmVmbHkiOwor
ICAgICAgZW1haWwgPSAiZmlyZWZseUBmaXJlZmx5Lm51IjsKKyAgICAgIHBhc3N3b3JkID0g
IntBUkdPTjJ9JGFyZ29uMmlkJHY9MTkkbT02NTUzNix0PTIscD0xJFJZVlZrRm9pM0ExeVlr
SThKMnpVd2ckR1VFUnZnSHZVOFNHalFtaWxESkdadTUwaFlSQUh3K2VqdHVMK1NreWdzOCI7
CisgICAgfQogICAgIHsKICAgICAgIHVzZXJuYW1lID0gImdsaXR0ZXJzaGFyayI7CiAgICAg
ICBlbWFpbCA9ICJncmZuQGd3cy5meWkiOwotLSAKMi4yNS4xCgo=

--07c9605219da4b40b95ea5a855089bfa--

